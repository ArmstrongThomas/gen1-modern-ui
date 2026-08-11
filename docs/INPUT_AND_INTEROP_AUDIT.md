# Pointer input and UI interoperability audit

Last updated: 2026-08-04

This audit records what released gen1recomp builds currently expose for
click/touch interaction, what Gen1 Modern UI can safely implement through the
released host hooks, and how redesigned flows should coexist with replacement
UI mods. The upstream contract is tracked in
[gen1recomp issue #807](https://github.com/bryanthaboi/gen1recomp/issues/807).

## Current engine input path

The released `input.pointer` middleware reports `pressed`, `moved`, `released`,
and `cancelled` phases with source, pointer ID, window-space coordinates,
deltas, pressure, and mouse button metadata. The engine calls the hook only
after `TouchControls` has had first refusal, and `return true` consumes the
pointer for the remaining lifecycle. Pointers that begin outside virtual
controls remain mod-visible even when they cross those controls later.
Focus/visibility recovery emits `cancelled` so mods can clean up captures.

The released `mod.input` facade provides source-isolated `tap(game, button)`
and tokenized `press(game, button)` / `release(token)` operations for the
normal Game Boy buttons (`up`, `down`, `left`, `right`, `a`, `b`, `start`, and
`select`). The engine cleans up held tokens during hot reload and input
recovery. The first two hooks are sufficient for reliable pointer events and
vanilla button parity; a semantic interaction model is still useful for
replacement screens whose layout cannot be inferred from public state.

## Implemented pointer layer

Gen1 Modern UI caches hit regions from the same live presenter geometry used to
draw each frame. Mouse movement over a supported row sets the live selection
field without activating it. Row taps then call the owning state through
`mod.input:tap(game, "a")`; they never invoke a row callback or private queue
directly. Dialogue and quantity cards use the same normal action path.
Captured touch IDs can scroll overflowing lists, while mouse or touch pointers
that begin on panel chrome can drag a panel. Normalized per-screen-family
offsets persist through `mod.save`. Desktop left/right clicks map to the
source-safe `A`/`B` actions even outside modern panels; drags suppress the
release action. Drag scrolling is quantized from the gesture origin with a
dead zone and row-height hysteresis, keeping long shop and inventory lists
stable under high-frequency move events.

Only the top presented layer can own hover or activation. Parent lists remain
visible beneath prompts, but a full modal blocker prevents their cursor from
moving. A click activates only if press and release resolve to the same live
target. Stack changes, in-place screen-mode changes, rebuilt row tables, modal
changes, cancelled pointers, and disabling pointer support all invalidate the
old capture. Empty placeholder rows are inert, and panel whitespace blocks the
global A fallback instead of activating a missing item. Only explicit panel
chrome is draggable; a small movement over an ordinary row cancels its click
instead of unexpectedly moving the whole interface.

Custom public-state adapters cover categorized Manager options, Manager
YES/NO/help overlays, Party action submenus, and Gen 3 PC box row/column grids.
Desktop screens that expose meaningful directional, `select`, or `start`
actions also render compact source-safe action buttons. Link code/address
editors expose all four arrows, while waiting/status rows are intentionally
non-interactive. The buttons are omitted when native TouchControls are visible
because the engine already owns those inputs.

Horizontal input for side-by-side YES/NO cards is translated without renaming
entries in `Input.pressQueue`. The old rewrite could turn a released RIGHT edge
into a source-less DOWN hold, leaving the player walking down until a real DOWN
press/release repaired the state. The current path removes the horizontal edge
and asks `mod.input:tap` for an atomic UP/DOWN edge, preserving source identity.

The layer is opt-in through the **TOUCH / CLICK UI** and **DRAG UI PANELS**
settings. Both experiments default off for new installs. Hosts that do not
expose the new APIs simply follow the existing keyboard/controller path.
Semantic actions
for atomic box transfer and other custom replacement screens remain future
adapter work. Mouse-wheel input is deliberately out of scope for now; lists use
hover, row clicks, keyboard/controller navigation, or captured drag scrolling.

## Native-to-pointer interaction matrix

The pointer contract follows each screen's released keyboard/controller model.
It improves targeting without bypassing the state that owns validation,
sounds, callbacks, networking, or stack order.

| Surface | Native contract | Pointer contract |
|---|---|---|
| Generic Menu, Start menu, title menu, PC root | UP/DOWN choose, A activates, B cancels; some menus let START close. | Hover selects a live row; matching click sends A. Right-click sends B. No callback is called directly. |
| Generic List, Bag, Shop, Player PC, Bill's PC | UP/DOWN choose, A activates, B cancels; optional L/R page jump and SELECT action. | Hover/click selects through the live index. Long lists drag-scroll by rows. Context buttons expose declared L/R/SELECT actions. |
| OptionsMenu and public OptionRows screens | UP/DOWN choose; L/R/A adjust or activate; B/START exits. | Hover selects; click sends A. L/R buttons call the same option step path. |
| YES/NO ChoiceBox | UP/DOWN toggles; A confirms after its normal hold; B selects NO/cancels. | Direct YES/NO targets select then send A. L/R buttons become source-safe UP/DOWN taps. Pending choices reject new pointer activation. |
| QuantityBox | UP/DOWN changes amount; A confirms; B cancels. | The amount card confirms with A; −/+ buttons send DOWN/UP. |
| Dialogue TextBox | A/B reveal, advance, or close according to live typewriter state. | Clicking the card sends A; right-click sends B. Dragging the card does not also advance it. |
| Party list | UP/DOWN chooses a Pokémon; A opens the engine-built action list; B backs out. | Hover/click targets party rows. Detail space is chrome, not a second action owner. |
| Party action submenu | UP/DOWN chooses an injected live action; A activates; B closes. | A modal blocker freezes the party cursor. Only submenu rows hover/click; actions still run through PartyMenu. |
| Pokédex list and side action menu | UP/DOWN choose; L/R page jump; SELECT changes view; A opens the side menu; B backs out. | Species rows click through A. PAGE and SELECT controls are explicit; the pushed side Menu becomes the sole active pointer layer. |
| Summary, Dex entry, Trainer Card | A or B advances/closes (Summary advances page before close). | The whole data card is a click-to-A surface; right-click remains B. |
| Mod Manager list/detail/options | UP/DOWN choose; L/R changes tab/detail/value; A activates; SELECT and START are context actions; B backs out. | Live rows hover/click, tabs are clickable, and the dock labels HELP/TOGGLE/APPLY where appropriate. Inert headers/status rows cannot activate. |
| Manager confirmations/help | UP/DOWN chooses YES/NO; A confirms; B cancels/closes. | Modal/scrim regions block underlying rows. YES/NO click through A; clicking the help card dismisses only presentation help. |
| Gen 3 PC box | Public zero-based row/column grid; arrows navigate; A pick/place; SELECT switches party/box; START opens stats. | Cells set row/column and send A. Arrow, PARTY/BOX, and STATS controls send the corresponding source-safe buttons. Atomic drag/drop is not inferred. |
| Link menus/trade list | UP/DOWN choose; A advances/chooses; B backs out. | Navigable rows hover/click normally. Networking and stage transitions remain LinkState-owned. |
| Link code/address editors | Arrows edit digit and slot; A connects; B backs out. | All four arrow controls are exposed. The primary editable row may send A; position/port/status rows are display-only. |
| Link waiting/running stages | Usually B cancel only. | Status rows are inert; right-click remains B. |
| Battle presenter | Native battle input and queues. | The presenter remains WIP/off by default, so the classic battle surface owns interaction. |
| Unknown/custom/capture screens | Screen-defined. | No inferred pointer adapter; the complete visible UI falls back to classic rendering. |

## Pointer safety invariants

- The top active layer is the only selectable layer.
- Press and release must match the same semantic target.
- A capture belongs to one stack state, screen mode, row model, and modal
  identity; any change invalidates it.
- Empty, disabled, header, status, and placeholder rows never send A.
- Clicking blank UI consumes the pointer but performs no global action.
- Clicking outside all UI maps left to A and right to B on desktop.
- A drag never also becomes a click. Rows scroll only when the list actually
  overflows; panel movement begins only on explicit chrome.
- Synthetic directions are atomic `mod.input:tap` calls. The mod never renames
  queued buttons or creates an unowned held direction.
- All field writes are bounds-checked and protected; callbacks remain engine-
  owned and execute through the normal input update.

## Installed inventory-mod findings

The installed category inventory mod is a standalone Useful Bag release. It
still uses a standard `ListMenu` and preserves live row objects, so the modern
presenter can display its current six-pocket projection. Its public runtime
shape includes the current `items`, `title`, `index`, `scroll`, pocket index,
and pocket IDs; the source mod continues to own projection, sorting, cursor,
and item callbacks. The legacy bridge recognizes that shape without invoking
its projection function. The drop-in contract migration is documented in
[`useful_bag_adapter.lua`](examples/useful_bag_adapter.lua).

Older Modern Bag builds that expose only a `modernBag` capability remain
supported through the same specialized presenter path when present.

Other installed inventory extensions also modify the live screen rather than
providing a common presentation model:

- Bag 999 replaces or sorts rows and wraps update/close.
- Item Shortcut adds ordinary action descriptors.
- Reusable Machines adds a move-name field that generic rows do not yet show.

Gen1 Modern UI must keep reading current rows and preserve their `source`
objects. It must never rebuild another mod's categories or callbacks. Generic
row presentation displays `right` or an explicit `displayValue`; opaque
`value` payloads are deliberately not stringified.

## Versioned presenter compatibility contract

The compatibility foundation is the versioned `mod.exports.gen1ModernUi`
contract. A v1 supporting mod may publish screen descriptors
with `match(state)`, a read-only `model(game, state)`, optional source-owned
semantic actions (`up`, `down`, `left`, `right`, `select`, `back`, `start`, and
`hover`), `layer`, and `canSuppressNative`. Models may contain title, rows,
selection, scroll, footer, details, assets, and public source references.

The same contract may declare data-only `themes` and `frames`. Frame IDs are
namespaced by the source mod, and assets must be host-resolved declared paths
or public image, texture, sprite, or catalog references owned by that source
mod. A source mod should resolve its private PNG through `mod.assets:image`
before publishing it. Nine-slice
rendering, nearest filtering, integer pixel scale, and the seven-pixel authored
inset are provided by Gen1 Modern UI. V1 screen/extension draw callbacks are
never accepted.

API v2 keeps the v1 lane intact and adds isolated custom surfaces. Surface
models, layouts, modals, and Gallery fixtures remain data-only; the single
descriptor-owned render callback runs on a private canvas with virtual pointer
coordinates and commits only after a successful frame. A false result,
exception, or graphics-state violation leaves native input and rendering
untouched.

Source mods can register explicitly through `mod.find("gen1_modern_ui").exports`
or expose their contract for discovery by a known integration. Gen1 Modern UI
never reaches into private modules or executes arbitrary files from another
mod. A source mod may load its own optional adapter file and then publish the
result through `mod.exports`.

The registry validates the contract, isolates match/model/action errors,
invalidates state caches on reload or disable, and falls back to the native
renderer on missing exports, unsupported versions, malformed data, or an
incomplete suppression proof. `screen.render_visible` is the preferred precise
suppression hook. Older hosts retain the `render.compose` UI-canvas clearing
fallback. The full contract example is in
[`UI_PRESENTATION_API.md`](UI_PRESENTATION_API.md#compatibility-contract-v1).

## Dialogue is first-class UI

Text boxes, YES/NO choices, quantities, and small action menus are not edge
cases; they connect almost every larger game flow. The P0 stack-aware layer
should present dialogue as a compact bottom card or bottom sheet while leaving
the world visible. Choices should be small attached modals rather than full
screen panels. Portrait layouts sit above the controls; landscape layouts may
occupy the tall center between the D-pad and A/B controls, and modest overlap
with START/SELECT is acceptable.

Presentation must preserve typewriter progress, waits, choice delays,
callbacks, and stack order. Tapping the text card advances it and tapping an
option selects it directly through the owning state's normal action path.

## DV Tracker compatibility

The DV Tracker third SummaryMenu page remains source-owned for navigation, but
the modern Summary presenter recognizes its public page marker and reads the
selected record's `dvs` and `statExp` tables. If either table is absent, the
page remains safe and renders an em dash for that value rather than falling
back to the first status page.

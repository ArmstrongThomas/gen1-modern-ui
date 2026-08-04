# Pointer input and UI interoperability audit

Last updated: 2026-08-03

This audit records what released gen1recomp builds currently expose for
click/touch interaction, what Gen1 Modern UI can safely implement without an
engine patch, and how redesigned flows should coexist with replacement UI
mods. The upstream source checked was `bryanthaboi/gen1recomp` `origin/dev` at
commit `8da51aa`.

## Current engine input path

There is no public gameplay pointer hook or semantic UI-action API today.

- `love.touchpressed`, `love.touchmoved`, and `love.touchreleased` call the
  corresponding `Game:touch*` methods.
- `Game:touch*` forwards exclusively to `TouchControls`, whose hit testing is
  limited to the virtual D-pad, A, B, START, and SELECT controls.
- `StateStack`, `Menu`, and `ListMenu` have no pointer dispatch. Menus consume
  Game Boy button edges from `game.input`.
- Gameplay mouse events are ignored unless the touch-emulation environment
  switch is enabled. The mouse wheel is reserved for overworld zoom.
- FlexLove supports pointer and drag interaction, but it is used by launcher
  and editor surfaces rather than the in-game `mod.ui` widgets.

The released `input.step` hook, available since gen1recomp v0.1.46, is the only
general in-game input seam. It runs before queued edges are promoted and before
the top state updates.

## Safe first implementation without an engine patch

A compatibility-first pointer layer is feasible as an opt-in experiment:

1. Cache presenter hit regions from `render.hud` in window coordinates.
2. Poll LÖVE touch and mouse state from `input.step`.
3. Track begin, move, release, and captured drag state inside this mod.
4. Ignore a pointer that begins inside a visible virtual-control hit region.
5. Map a hit to the live state selection, then synthesize the normal Game Boy
   action so the original state performs validation, sounds, callbacks, stack
   changes, and timing.

This can provide taps for standard menus and adapter-backed screens, but it is
not a complete public contract. Injecting a button currently requires either
touching `game.input.pressQueue` or sharing the virtual controller's overlay
source. Polling can also miss a very short press/release between fixed ticks.
For those reasons, pointer support should ship experimental and default-off
until the engine exposes the small hooks below.

## Recommended upstream hooks

1. An `input.pointer` middleware event carrying `phase`, `source`, `id`, `x`,
   `y`, `dx`, `dy`, and pressure where available. Mouse input should enter this
   path even when touch emulation is disabled. `TouchControls` should report
   whether it captured the pointer so the virtual controller retains priority.
2. A source-safe public facade such as `mod.input:tap(game, button)` plus
   tokenized press/release operations. This avoids collisions between a UI
   tap, a held physical key, and the on-screen controls.
3. An optional semantic interaction model for screens that want to expose
   actions, tabs, items, and drag/drop targets independently of visual layout.

The first two hooks are sufficient for reliable pointer events and vanilla
button parity. The third is what makes direct navigation durable across
arbitrary replacement screens.

## Improving flow without bypassing other mods

The modern presentation is not required to copy the original 160x144 layout
or force the same number of visible steps. The safe rule is to improve the
layout and shortcuts while letting the live state own the resulting action.

| Surface | Compatibility-safe direct interaction |
|---|---|
| Generic Menu/List | Set its live selection and inject A. Do not call a row callback directly; the state owns pop order, `keepOpen`, and sounds. |
| Options | Select the live row, then inject left/right/A so custom `step` and `activate` functions still run. |
| Pokédex | Tap a species to select + A. A DATA shortcut can be a short two-tick macro through the real side menu, preserving another mod's `onChoose`. |
| Party | Select a card + A to build the real action list, including actions injected by other mods; then activate the selected live action normally. |
| Bag tabs | Requires a bag-specific adapter because category state is not part of the standard `ListMenu` contract. |
| Box drag/drop | Requires an adapter that translates drag intent into the screen's normal pick/place operations; no public atomic transfer API exists. |
| Dialogue | Tap-to-advance can inject A/B. A public reveal/advance method would be preferable because held A/B currently only accelerates typing. |
| YES/NO | Select the live choice + A, preserving its delay and callback ownership. |
| Quantity | Buttons can inject repeated up/down edges; a slider needs a semantic setter or adapter. |
| Naming | Set the live grid row/column and inject A; the grid already includes mod-provided glyph changes. |

Direct cards, tabs, previews, and action shortcuts are therefore part of the
design direction. They should be capability-driven rather than inferred from
localized labels or private state shapes.

## Installed inventory-mod findings

The installed category inventory mod is Modern Bag 1.2.0. It still uses a
standard `ListMenu` and preserves live row objects, so the generic presenter
can display its current category rows. It stores pocket/cursor/swap state in a
private `list.modernBag` table, rebuilds the rows during update, and wraps draw.
It exports category definitions but not the current pocket or a semantic
pocket setter.

Other installed inventory extensions also modify the live screen rather than
providing a common presentation model:

- Bag 999 replaces or sorts rows and wraps update/close.
- Item Shortcut adds ordinary action descriptors.
- Reusable Machines adds a move-name field that generic rows do not yet show.

Gen1 Modern UI must keep reading current rows and preserve their `source`
objects. It must never rebuild another mod's categories or callbacks. Generic
row presentation displays `right` or an explicit `displayValue`; opaque
`value` payloads are deliberately not stringified.

## Presenter adapter direction

A future adapter registry should be versioned and namespaced. An adapter may
match a stable `screenId` or state capability and return a read-only semantic
model containing title, rows, tabs, cards, selection, scroll, footer, details,
and source references. It should also declare `layer = "screen" | "modal"`
and whether it can safely suppress classic drawing for the complete visible
stack. Errors or missing capabilities must immediately fall back to vanilla.

Optional semantic actions may translate a tap or drag into the screen's normal
input/state operation, but adapters must not replace gameplay callbacks. For a
category bag, the ideal exporting mod contract is a `bagModel(list)` reader and
`selectPocket(list, pocketId)` action that saves cursors, clears swap state,
and refreshes rows through that mod's own implementation.

## Dialogue is first-class UI

Text boxes, YES/NO choices, quantities, and small action menus are not edge
cases; they connect almost every larger game flow. The P0 stack-aware layer
should present dialogue as a compact bottom card or bottom sheet while leaving
the world visible. Choices should be small attached modals rather than full
screen panels. Portrait layouts sit above the controls; landscape layouts may
occupy the tall center between the D-pad and A/B controls, and modest overlap
with START/SELECT is acceptable.

Presentation must preserve typewriter progress, waits, choice delays,
callbacks, and stack order. Once pointer input is available, tapping the text
card advances it and tapping an option selects it directly.

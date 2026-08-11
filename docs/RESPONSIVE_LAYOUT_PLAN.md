# Responsive Layout and Scaling Plan

Preset envelopes are the foundation of the layout contract. Pure content sizing would cause resize jitter as players move between pages or selections, while fixed oversized canvases create unnecessary empty space.

This document records the agreed design before source dimensions are changed.

## Preset envelopes

Outer containers use stable presets in logical units at 100% UI scale:

| Preset | Preferred size | Intended screens |
|---|---:|---|
| XS | 320×200 | Confirmations, quantities, small choices |
| S | 400×300 | Start menu, short menus, submenus |
| M | 600×420 | Options, Mod Manager, long generic lists |
| L | 760×540 | Party, Pokédex, Bag, Shop, Summary, Trainer Card, Dex entries |
| XL | 960×640 | Box grids, Naming, Town Map, Dex Radar, MMO screens |
| Battle Wide | 640×360 | Modern 2D WIDE battle presentation |

These are preferred envelopes, not mandatory physical sizes. They are capped to the safe viewport and reflow internally.

Multi-page screens lock their chosen envelope when opened. Changing Summary pages, Pokémon, trainer pages, extension pages, or list selection must not resize the frame. Only these events may choose a new envelope:

- Window or safe-area change
- Orientation change
- UI or font setting change
- Theme or frame change
- Reopening the screen

Simple menus may choose S or M based on their complete row set, but that choice is also locked while open.

## Sizing strategy

The solution combines smaller, consistent defaults with measured content. Content is not automatically enlarged merely to consume empty space.

Each screen gets:

1. A stable preset outer rectangle.
2. A frame rectangle.
3. A precisely derived interior rectangle.
4. Fixed header and footer regions measured from real fonts.
5. A flexible body that wraps, reflows, or scrolls.

Rows no longer share one guessed height. Each row is measured independently, including:

- Wrapped label lines
- Value and status columns
- Icons and badges
- Secondary text
- Actual font line height

Drawing, scrolling, and pointer hitboxes all use those same calculated row rectangles.

## Plain Pixel contract

Plain Pixel remains strictly whole-number scaled:

- 1× raster: 15 px
- 2× raster: 30 px
- 3× raster: 45 px
- 4× raster: 60 px

It is never rendered to a canvas and fractionally rescaled.

The real font currently reports 28/56-pixel OpenType line boxes for 15/30-pixel rasters. That disagreement is a major source of bad spacing. The implementation defines explicit pixel-font metrics around its authored 11-pixel glyph cell and 15-pixel raster step, with fallback glyphs verified before the line advance is finalized.

If a requested pixel-font step cannot fit:

1. Reflow columns.
2. Wrap content.
3. Enable scrolling.
4. Reduce chrome and spacing.
5. Drop to the next lower whole font step if still necessary.

The effective cap should be exposed so the setting can indicate when a screen constrained it.

## Responsive behavior

The shared layout engine supports four main viewport modes:

- Portrait: one-column layouts, with wide source art above details.
- Short landscape: compact headers and footers, with split columns where useful.
- Standard desktop: content-sized centered cards.
- Ultrawide: capped workspace width; panels do not stretch across the monitor.

Every panel is bounded by the safe area after accounting for touch controls and frame ornamentation.

For normal screens, width and height may clamp independently so content can reflow in portrait. The WIDE battle composition preserves its aspect ratio in landscape.

## WIDE battle plan

The modern 2D battle presenter activates only with explicit proof that the source is using WIDE layout. `false`, missing metadata, or unknown geometry remains entirely native.

Legacy `battleUiMode` values are accepted for save compatibility, but every
eligible source uses this one bounded composition; none select the old
unbounded scene-HUD geometry.

The 640×360 landscape design contains:

- A 608×288 arena interior, matching the 304×144 source at exactly 2×.
- Status cards inside the arena.
- Move, action, and message panels contained within the complete 640×360 envelope.
- One source-to-screen transform shared by framing, paper cleanup, animations, pointer regions, and native HUD scrubbing.

The cleaned source canvas is captured before the host applies its independent
letterbox scale, removed from that original placement, and composited into the
authoritative arena rectangle. This keeps the complete source scene and its
palette zones while preventing an oversized second copy behind the fixed HUD.

For portrait, the source remains WIDE but uses a 360×640 shell. The opponent
status occupies a stable slot above the wide arena, while the player status and
command regions remain below it. The two battlers must never read as one stacked
status block.

The frame API derives one authoritative interior edge. Battle paper and all children are clipped to that rectangle, eliminating white spill beyond the inside edge of the border.

## Overflow detection

A shared layout context records every panel, text block, row, icon, and pointer region.

Before drawing, it verifies:

- Child bounds remain inside their assigned content region.
- Panels remain inside the safe viewport.
- Rows do not intersect.
- Text fits or has an explicit wrap/truncate policy.
- Pointer regions match visible geometry.
- Frame decoration expands symmetrically.

Production behavior reflows, scrolls, caps scale, and finally clips. Development tests can fail with the exact screen and offending rectangle. An optional layout-debug overlay may outline overflow in red.

## Test matrix

Every existing presenter family is exercised across:

- 320×180 and 640×360 compact landscape
- 360×640 and 390×844 portrait
- 1024×768 and 1280×1024 classic aspect ratios
- 1280×720, 1600×1000, and 1920×1080 desktop
- 2560×1440, 3440×1440, 3840×2160, and 5120×2784 large, ultrawide,
  4K, or 5K displays
- Touch-control safe areas
- System font through manual 400% and AUTO 500%
- Plain Pixel at 1×, 2×, 3×, and 4×
- UI scale at 75%, 100%, 150%, 200%, 300%, 400%, and AUTO
- Combined maximum-scale stress cases

Tests also confirm that outer frames remain identical while changing pages, Pokémon, selections, and extension content.

The in-game [UI Gallery](UI_GALLERY.md) exposes the same production presenters
with stable IDs and temporary UI-scale, font-scale, font-mode, and content-level
controls. It complements the automated matrix with an actual-save inspection
path and never persists its temporary scale overrides.

## Implementation order

Proceed foundation-first:

1. Measurement primitives and preset envelopes.
2. Generic menus and dialogue.
3. Rich screens.
4. Workspace screens.
5. Fixed WIDE battle layout.

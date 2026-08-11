# Readability and scaling plan

Last updated: 2026-08-04

The follow-up [responsive layout and scaling plan](RESPONSIVE_LAYOUT_PLAN.md)
defines stable preset envelopes, whole-step Plain Pixel scaling, overflow
checks, and the WIDE-only modern battle layout.

## Implementation status

The v0.7.3 implementation ships the independent UI, font, and dialogue scale
settings described below. Effective themes are cached by authored theme,
density, scale values, opacity, and viewport class; fonts are cached by
effective pixel size. Generic menu rows measure live labels and values before
layout, grow to a readable two-line minimum when the content cannot coexist in
one row, and dialogue wraps the currently revealed text without changing the
typewriter cursor. Rich presenters consume the same scaled typography,
spacing, density, and metric tokens; their height ceilings now grow with the
active readability scale on large safe viewports so larger screens reveal more
rows instead of only enlarging existing rows. The remaining acceptance work is
released-game screenshot QA across every rich presenter, theme, and opacity
combination.

This milestone adds independent interface and text sizing without changing
the original menu state, cursor behavior, callbacks, or game logic. It is the
recommended next implementation slice after the v0.6.2 floating-screen fix.

## Proposed settings

Both scale controls also accept `AUTO`. It resolves a bounded five-percent
value from the safe window dimensions at render time, using both dimensions in
landscape and the limiting width in portrait.

- **UI SCALE** — 75% to 150% in 5% steps plus 175% to 400% high-resolution
  presets in 25% steps, default 100%. Scales panel padding, row height, icons,
  borders, radii, and control-hint spacing.
- **FONT SCALE** — 80% to 200% in 5% steps plus 225% to 400%
  high-resolution presets in 25% steps, default 100%. Scales title, body,
  caption, values, and control-hint fonts independently from panel chrome.
- **DIALOGUE TEXT SCALE** — Inherit, 110%, 125%, 150%, 175%, or 200%.
  Defaults to Inherit and applies an optional readability boost to dialogue,
  choices, quantities, and confirmation prompts. Their interior spacing and
  geometry grow with the effective text step so the ratio remains balanced.

Existing **UI DENSITY** remains a content-density preference. Scale controls
change physical size; density controls how tightly that size is arranged.
One-tap Large Text and Extra Large Text presets can follow after gen1recomp
exposes a public option setter; they should not depend on private ManagerState
internals to rewrite several saved values.

## Layout contract

Scaling must happen before measurement and layout. The presenter must create
the scaled font, measure live labels and values, calculate wrapping and row
height, and only then choose panel dimensions and visible-row counts. Scaling
the completed canvas is not acceptable because it blurs text, breaks wrapping,
and leaves input hints or borders at the wrong size.

- Font scale never changes Pokémon or item artwork proportions.
- Images remain aspect-fit with nearest-neighbor filtering.
- A larger font raises the minimum row height automatically.
- Dialogue rewraps from live revealed text without advancing its typewriter.
- When content cannot fit, prefer wrapping, scrolling, paging, or a narrower
  detail pane before truncating essential values.
- Compact floating panels remain content-sized; rich panels use scale-aware
  width and height budgets and remain clamped to the safe viewport.
- Full Screen uses the same scaled content rules over its themed backdrop.
- Portrait and landscape layouts may choose different row counts, but must
  preserve the live cursor, scroll, and callbacks.
- Minimal UI removes optional detail first; it must not force smaller text.

## Implementation outline

1. Add the option schema and a single effective-scale resolver.
2. Cache fonts by effective pixel size and cache scaled theme metrics by
   theme, density, UI scale, font scale, and viewport class.
3. Replace fixed text/row assumptions with measured minimums in generic menus,
   dialogue, Party, Pokédex, Trainer Card, Bag/Shop/PC, boxes, and mod options.
4. Give dialogue its optional multiplier and reflow its choice/quantity cards
   from the same effective body font.
5. Show the effective percentage in option descriptions and keep scale changes
   independent from theme, opacity, layout style, and Minimal UI.
6. Document the scale tokens in the public theme API so external themes remain
   compatible and do not need to hard-code one font size.

The shared scaled theme and minimum-row resolver described in steps 1–6 ship
in v0.7.0. The v0.7.1 follow-up made rich-screen height budgets scale-aware;
the v0.7.2 follow-up hardened UTF-8 name rendering and added Nidoran gender-name
regression coverage. The v0.7.3 follow-up makes minimal and rich presenter
width budgets scale-aware so larger text is not clipped by reference-width
ceilings, standardizes nested modal placement, and adds responsive AUTO values
for UI and font scale. Released-game screenshot QA and any screen-specific
polish remain follow-up work.

## Compatibility and performance

- Read live third-party rows every frame, as today; scaling must not copy or
  replace their callbacks.
- Unknown/custom screens retain the classic fallback.
- Font objects and derived theme metrics are cached rather than recreated each
  frame.
- Option changes invalidate only affected caches and update immediately.
- Other mods' custom font/theme assets must receive the same effective size
  request and keep their existing fallback behavior.

## Acceptance tests

- 80%, 100%, 125%, 150%, 200%, 300%, 400%, and AUTO font cases on desktop,
  portrait phone, short landscape phone, 4K, and 5K viewports.
- Dialogue with one line, several wrapped lines, YES/NO, quantity, and a long
  localized string at each planned dialogue scale.
- Empty, short, full, and scrolling Start, Bag, Pokédex, Party, PC, and mod
  option lists.
- Minimal UI, every built-in theme, both layout styles, and panel/text opacity
  extremes.
- Long labels and right-column values never overlap; essential HP, PP, prices,
  and counts remain legible.
- Touch controls remain usable, while keyboard/controller behavior is
  unchanged.
- Repeated scale changes do not leak font objects or create per-frame cache
  churn.

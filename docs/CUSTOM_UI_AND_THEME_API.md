# Gen1 Modern UI: custom UI and theme API

This is the source-modder guide for the Gen1 Modern UI compatibility contract.
It lets a mod publish presentation data, semantic actions, themes, pixel
frames, and optional artwork without giving Gen1 Modern UI access to private
modules or private state.

The contract is deliberately data-first:

- The source mod owns state, validation, callbacks, networking, and side
  effects.
- Gen1 Modern UI owns the shared layout, typography, scaling, palette, and
  nearest-neighbor frame renderer.
- Models are read-only snapshots. They must not contain functions.
- Custom draw callbacks and arbitrary custom coordinate systems are not
  supported.
- If an adapter is missing, disabled, on an unsupported API version, malformed,
  or throws while matching/building a model, that screen falls back to the
  native UI for that frame.

## Dependency and discovery

Declare a dependency on `gen1_modern_ui`. The UI discovers a public
`mod.exports.gen1ModernUi` table from known source-mod IDs. A future or
third-party mod can also register explicitly through the public export:

```lua
local ui = mod.find("gen1_modern_ui")

if ui and ui.exports and ui.exports.registerAdapter then
  ui.exports.registerAdapter({
    owner = mod.id,
    contract = mod.exports.gen1ModernUi,
  })
end
```

The source mod must publish the same table from its own entry file. The
`owner` must be the source mod's ID and the source mod must be active. Use a
stable namespaced screen ID and keep the public state fields documented by the
source mod.

## Contract shape

```lua
mod.exports.gen1ModernUi = {
  apiVersion = 1,

  screens = {
    ExampleProfile = {
      match = function(state)
        return state.screenId == "example_profile"
      end,

      model = function(game, state)
        return {
          title = "PROFILE",
          rows = state.publicRows or {},
          index = state.cursor or 1,
          scroll = state.scroll or 0,
          footer = { "A select", "B back" },
          details = state.publicDetails,
          assets = {
            portrait = state.publicPortrait,
          },
        }
      end,

      actions = {
        up = function(game, state) return state:move(-1) end,
        down = function(game, state) return state:move(1) end,
        left = function(game, state) return state:previousPage() end,
        right = function(game, state) return state:nextPage() end,
        select = function(game, state) return state:select() end,
        back = function(game, state) return state:back() end,
        start = function(game, state) return state:openOptions() end,
        hover = function(game, state, index)
          return state:preview(index)
        end,
      },

      layer = "screen",
      canSuppressNative = true,
    },
  },
}
```

`match` and `model` receive the live game/state objects owned by the source
mod. Keep the functions small and defensive. Never return the state object
itself as a model; construct a new presentation table from public fields.

Supported semantic actions are `up`, `down`, `left`, `right`, `select`,
`back`, `start`, and `hover`. The callbacks are still source-owned operations;
the presenter only routes keyboard, controller, pointer, and touch intent to
them. A callback may return whatever the source mod normally returns.

### Battle screens

Battle adapters use `layer = "battle"` and the same version negotiation and
error isolation as ordinary screens. A battle model may additionally publish
read-only `phase`, `presentation`, `player`, `enemy`, `moves`, `message`,
`isVoxelBattle`, and `overlays` fields. `overlays` accepts data such as:

```lua
overlays = {
  experience = { current = 14, maximum = 100 },
  caughtIndicator = { caught = true },
  catchRates = { pokeball = 18, greatBall = 32, ultraBall = 48 },
}
```

These values are presentation hints only. The source mod calculates them and
continues to own battle validation, timing, callbacks, networking, and state
transitions. `presentation = "hud"` or `isVoxelBattle = true` asks AUTO mode
to use compact voxel-safe menu/status placement. All battle modes retain the
native/source draw and its animations; `canSuppressNative` is ignored for
`layer = "battle"`. Malformed or throwing adapters fall back to the native UI.
No third-party draw callbacks are accepted. See
[`examples/battle_adapter.lua`](examples/battle_adapter.lua).

## Models and rows

The model may contain:

| Field | Purpose |
| --- | --- |
| `title` | Screen title text. |
| `rows` | Array of strings, numbers, or row tables. This is required. |
| `index` | One-based selected row. Invalid values are clamped safely. |
| `scroll` | Zero-based scroll offset. Invalid values are clamped safely. |
| `footer` | Optional public footer/help data. |
| `details` | Optional read-only detail data for the generic presenter. |
| `assets` | Optional public image/catalog table used by rows. |

Common row fields are:

```lua
{
  label = "PLAYER",
  value = "TOMMY",       -- right-aligned value
  image = "portrait",    -- key in model.assets, or a public image reference
  enabled = true,
  header = false,
  category = false,
  marker = true,
  source = { publicId = "player-42" },
}
```

`value` may also be supplied as `right` by presenters that already use that
name. Artwork may be supplied through `image`, `icon`, `thumbnail`, `sprite`,
or `asset`. A string is first resolved through `model.assets` and otherwise is
treated as a host-resolved public reference. Missing optional artwork leaves a
text-only row instead of failing the screen.

Artwork can be a public image/texture object, a public sprite/catalog
descriptor, or a source-owned path resolved by the source mod. Gen1 Modern UI
aspect-fits it and keeps nearest-neighbor filtering. It does not load an
arbitrary path from a sibling mod's private directory.

For a source-owned PNG, resolve it in the source mod and publish the resulting
public image object:

```lua
local portrait = mod.assets:image("assets/portrait.png")

mod.exports.gen1ModernUi = {
  apiVersion = 1,
  screens = {
    ExampleProfile = {
      match = function(state) return state.screenId == "example_profile" end,
      model = function(game, state)
        return {
          title = "PROFILE",
          rows = {
            { label = state.name, image = "portrait" },
          },
          assets = { portrait = portrait },
          index = 1,
        }
      end,
    },
  },
}
```

Images are presentation resources only. The source mod remains responsible
for selecting the right sprite, palette, animation frame, and ownership data.

## Themes

Themes are data-only token tables. A contract can publish any number of
themes; each one is registered under the source mod's namespace and added to
the live UI theme selector.

```lua
themes = {
  lavender = {
    name = "Lavender",
    colors = {
      backdrop = { 0.08, 0.05, 0.14, 1 },
      surface = { 0.15, 0.11, 0.24, 1 },
      surfaceRaised = { 0.23, 0.18, 0.34, 1 },
      selected = { 0.32, 0.48, 0.78, 1 },
      accent = { 0.72, 0.62, 1.00, 1 },
      text = { 0.98, 0.97, 1.00, 1 },
      textMuted = { 0.78, 0.80, 0.92, 1 },
      onAccent = { 0.04, 0.03, 0.08, 1 },
      divider = { 0.42, 0.43, 0.60, 1 },
      health = {
        track = { 0.18, 0.20, 0.30, 1 },
        high = { 0.14, 0.78, 0.74, 1 },
        medium = { 0.98, 0.76, 0.22, 1 },
        low = { 1.00, 0.48, 0.18, 1 },
        critical = { 0.86, 0.43, 0.96, 1 },
      },
    },
    typography = { title = 24, body = 17, caption = 13 },
    spacing = { xs = 5, sm = 9, md = 13, lg = 18, xl = 26 },
    radii = { sm = 8, md = 16, lg = 22 },
  },
  paper = {
    name = "Paper",
    colors = {
      surface = { 0.98, 0.98, 0.94, 1 },
      surfaceRaised = { 0.88, 0.89, 0.84, 1 },
      selected = { 0.42, 0.64, 0.88, 1 },
      text = { 0.04, 0.05, 0.08, 1 },
      textMuted = { 0.24, 0.29, 0.36, 1 },
      divider = { 0.36, 0.43, 0.52, 1 },
    },
  },
}
```

Theme colors should not communicate state through hue alone. Use strong
lightness separation for `text`, `textMuted`, `surface`, `surfaceRaised`, and
`selected`; keep dividers visibly darker or lighter than their surface; and
give HP states distinct luminance as well as distinct hues. Numeric HP labels
remain the authoritative status cue. The built-in Light, Dark, Classic Mono,
and other palettes are examples of this approach.

Themes may also provide `frame`, `density`, `metrics`, `spacing`, `radii`, and
`typography` tokens. Unspecified values inherit the Gen1 Modern defaults.
Theme IDs in a contract are automatically namespaced as `source_mod_id:name`;
an already-qualified ID may be used when it is owned by the source mod.

## Pixel frames

Contracts can publish multiple frames in the same table. Frames appear in the
PIXEL FRAME selector and can be referenced by a theme's `frame.asset`.

```lua
frames = {
  profile = {
    name = "Profile Frame",
    asset = mod.assets:image("assets/profile-frame.png"),
  },
  arcade = {
    name = "Arcade Frame",
    asset = mod.assets:image("assets/arcade-frame.png"),
  },
}
```

The PNG is rendered as a nearest-neighbor nine-slice: corners remain fixed,
horizontal and vertical edges repeat along their axis, and the center tiles.
`pixelScale` is constrained to an integer from 1x through 4x. The standard
`pixelInset` is seven source pixels, so a frame can reserve transparent
ornament outside the UI while the solid UI fill meets the authored inner edge.
Useful optional frame tokens are:

```lua
frame = {
  style = "pixel",       -- "pixel", "soft", or "none"
  asset = "source_mod_id:profile",
  slice = 24,
  pixelScale = 2,
  pixelInset = 7,
  width = 3,
  corner = 12,
  inset = 2,
  margin = 4,
  step = 4,
  shadow = 2,
}
```

Use source-owned `mod.assets:image(...)` objects for frame assets. Do not
expect Gen1 Modern UI to read another mod's private file path.

For a theme-only mod that has no custom screen, the public API also accepts
direct registration:

```lua
local ui = mod.find("gen1_modern_ui")
if ui and ui.exports then
  ui.exports.registerTheme({
    id = mod.id .. ":paper",
    owner = mod.id,
    name = "Paper",
    colors = { surface = { 0.98, 0.98, 0.94, 1 } },
  })
  ui.exports.registerFrame({
    id = "paper",
    owner = mod.id,
    name = "Paper Frame",
    asset = mod.assets:image("assets/paper-frame.png"),
  })
end
```

Re-registering an ID refreshes its label and tokens without duplicating the
selector entry. When the source mod is disabled or reloaded, its registered
themes and frames are removed from the live choices.

## Suppression, lifecycle, and fallback

Set `canSuppressNative = true` only when the source screen is fully represented
by the public model and semantic actions. Gen1 Modern UI prefers the host's
`screen.render_visible` hook so hidden native drawing does not affect state or
input. Older hosts use the existing `render.compose` clearing fallback.

The adapter cache is refreshed when public exports are discovered, replaced,
or removed. A source mod can call `unregisterAdapter(mod.id)` during reload if
it explicitly registered itself. A stale adapter, malformed model, failed
theme/frame registration, or callback exception removes only that adapter and
leaves the native screen available.

The compatibility layer never invokes arbitrary files supplied by another mod,
never reaches through private modules, and never accepts custom rendering
callbacks. This keeps future source-mod UI files safe to ship alongside their
own mods while preserving a conservative vanilla fallback.

## Testing checklist

Before publishing a contract, test:

1. The source mod is absent and disabled.
2. `apiVersion` is missing or older than the supported version.
3. `match` returns false, returns malformed values, or throws.
4. `model` changes rows, cursor, scroll, details, portraits, and map markers.
5. Every semantic action still reaches the source mod's validation and
   callbacks.
6. Optional images are missing, animated, palette-aware, or unavailable.
7. Multiple themes and frames can be selected and are removed after reload.
8. Light/dark/high-contrast palettes remain readable with large fonts,
   responsive scaling, pixel fonts, and the seven-pixel frame inset.

The copy-paste starter and current integration templates are available in the
[`docs/examples`](examples/README.md) directory:

- [`gen1_modern_ui_adapter.lua`](examples/gen1_modern_ui_adapter.lua)
- [`dex_radar_adapter.lua`](examples/dex_radar_adapter.lua)
- [`rby_mmo_adapter.lua`](examples/rby_mmo_adapter.lua)
- [`useful_bag_adapter.lua`](examples/useful_bag_adapter.lua)
- [`option_rows_adapter.lua`](examples/option_rows_adapter.lua)

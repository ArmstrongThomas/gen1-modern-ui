# Gen1 Modern UI: custom UI and theme API

This is the source-modder guide for the Gen1 Modern UI compatibility contract.
It lets a mod publish presentation data, additive UI extensions, semantic
actions, themes, pixel frames, and optional artwork without giving Gen1 Modern
UI access to private modules or private state.

The original v1 contract is deliberately data-first:

- The source mod owns state, validation, callbacks, networking, and side
  effects.
- Gen1 Modern UI owns the shared layout, typography, scaling, palette, and
  nearest-neighbor frame renderer.
- Models are read-only snapshots. They must not contain functions.
- v1 `screens` and `extensions` do not accept custom draw callbacks or
  arbitrary coordinate systems. They remain supported without modification.
- An `apiVersion = 2` contract may additionally declare an isolated custom
  `surface`. A surface is the only compatibility descriptor that accepts a
  render callback; its model, layout, Gallery fixtures, themes, and frames are
  still data-only.
- If an adapter/extension is missing, disabled, on an unsupported API version, malformed,
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
`owner` must be the source mod's ID and the source mod must be active. A
contract may contain `screens`, `extensions`, or both. An `apiVersion = 2`
contract may also contain `surfaces`. It may additionally contain a
`battle.native3d` ownership callback; see [Native 3D battle ownership](#native-3d-battle-ownership).
Use stable namespaced IDs and keep the public state fields documented by the
source mod.

### Version negotiation and backward compatibility

Keep `apiVersion = 1` when a mod only needs the established data-first
`screens` and `extensions` API. Those contracts are not reinterpreted as
custom surfaces, and their model/action behavior remains backward-compatible.
Use `apiVersion = 2` only when the contract needs a v2 capability such as
`surfaces`, `details.custom_fields`, `details.footer_lists`, or a declarative
`modal_overlay`.

The host publishes `compatibilityApiVersion = 1`, `surfaceApiVersion = 2`, a
`supportedApiVersions` list, and capability checks. A source mod can negotiate
without guessing the installed Modern UI version:

```lua
local ui = mod.find("gen1_modern_ui")
local supportsSurface = ui and ui.exports
  and ui.exports.supports
  and ui.exports.supports("custom_surface", 2)
```

Do not silently downgrade a custom surface to a v1 screen: v1 intentionally
has no render callback. If v2 is unavailable, leave the source mod's native UI
active.

## v1 data-first contract shape

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

For `apiVersion = 1`, supported semantic actions are `up`, `down`, `left`,
`right`, `select`, `back`, `start`, and `hover`. The callbacks are still
source-owned operations; the presenter only routes keyboard, controller,
pointer, and touch intent to them. A callback may return whatever the source
mod normally returns.

An `apiVersion = 2` shared screen may also declare additional non-empty named
actions. Normal navigation still routes through the semantic names above; the
extra names are targets for options in a data-only `modal_overlay` returned by
one of those semantic callbacks. This leaves v1 behavior unchanged and keeps
all executable behavior in the source-owned descriptor.

## Additive extensions

Use `extensions` when a source mod wants to add information or an action to a
screen that Gen1 Modern UI already knows how to present. An extension does not
replace a screen and never supplies a draw callback. Its `model` returns only
the pieces to merge into the built-in presenter:

```lua
extensions = {
  partyDetails = {
    match = function(state, kind)
      return kind == "party" or kind == "summary"
    end,

    model = function(game, state, kind)
      if kind == "party" then
        local rows = {}
        for index, mon in ipairs(state.party or {}) do
          local gender = mon.gender
          rows[index] = {
            badge = gender == "F" and { text = "♀", color = "accent" }
              or gender == "M" and { text = "♂", color = "accent" }
              or nil,
          }
        end
        return { rows = rows }
      end
      local mon = state.mon or {}
      return {
        pages = {
          {
            id = "extra-stats",
            title = "EXTRA STATS",
            rows = {
              { label = "ABILITY", value = mon.abilityName },
              { label = "NATURE", value = mon.natureName },
            },
          },
        },
      }
    end,

    -- PartyMenu exposes this source-owned submenu seam. The callback is
    -- still responsible for opening the source mod's own screen/state.
    menu = function(game, mon, context)
      return { { id = "details", label = "DETAILS" } }
    end,
    actions = {
      details = function(game, partyState, payload)
        -- Open or update a source-owned state here.
      end,
    },
  },
},
```

Supported additive model fields are:

| Field | Use |
| --- | --- |
| `rows[index]` | Merge presentation fields into an existing built-in row. `index` may also be placed inside the row patch. |
| `background` / `backgroundColor` | Fill an existing row with a theme color name or RGBA table. `selectedBackground` optionally controls the focused row. |
| `badge` | A short trailing label or public image such as a gender sign. Use `{ text, image, color, background, textColor }`; colors may be theme color names or RGBA tables. |
| `image` | A public leading icon or image/catalog reference for a row. |
| `assets` | Names the extension's public image references for string row fields. |
| `pages` for `trainer_card` | Data-only rows for an additive Trainer Card detail page. The native card remains the host state and closes normally. |
| `pages` | Data-only pages appended to the built-in Summary or Pokédex entry page flow. Page rows use the same row fields as ordinary adapters. |

The current additive targets are Party rows, Bill's PC Pokémon rows,
Pokédex/list rows, Pokédex entry pages, and Summary pages. Summary extension
pages are entered from the built-in second page with A/B; Pokédex entry pages
use the next A/B press. Both return to the built-in page with LEFT on their
first extension page and close with A/B like the native screen. Multiple
extension pages use LEFT/RIGHT to move between them. Party `menu` entries are appended through the released
`ui.party.submenu` hook; `actions` receive `(game, partyState, payload)` and
remain responsible for their own validation and state transitions.

All extension model output is copied and rejected if it contains functions.
Only the declared `actions` and the `menu`/`match`/`model` descriptor callbacks
may execute. This keeps the extension layer additive and prevents a source mod
from accidentally replacing the shared renderer.

The page host also includes the built-in Trainer Card. Match
`kind == "trainer_card"` and return a `pages` array to add a detail page;
the next A/B press enters it because the native Trainer Card has one page.
The shared extension-page renderer owns layout and rows, while the native card
still owns its state, portrait, badge grid, and close behavior.

For battle/voxel UI refinements, an extension may return a data-only `battle`
table. The current presenter supports `battle.cardWidth` (clamped to a safe
range) so an add-on can tune cards in an explicitly detected 2D WIDE battle
without copying the battle renderer or taking ownership of BattleState. This
does not opt standard 160x144 or 3D/voxel battles into Modern UI.

### Native 3D battle ownership

Voxel battle mods that own the complete 3D scene and its child interfaces can
declare that ownership explicitly at the contract level:

```lua
mod.exports.gen1ModernUi = {
  apiVersion = 1,
  battle = {
    native3d = function(game, state)
      return mod.options:get("battleUi") ~= false
    end,
  },
  extensions = {
    -- Optional data-only refinements for compatibility testing.
  },
}
```

When `native3d` returns true, Modern UI leaves the complete BattleState stack
alone: the battle field, HUD, dialogue, Party/Bag/choice menus, level-up
windows, native drawing, cleanup, and battle input remapping remain source
owned. The callback is read-only and must not mutate state.

Modern UI also recognizes the released DramaticShape public export
(`exports.lib.require("OverworldBattle").enabled()`) for the known
`dramatic_shape`/`dramatic_shape_voxel` IDs. This lets the Modern UI setting
`LEAVE 3D BATTLES ALONE` protect 3D-BTL battles even when DramaticShape does
not publish a Modern UI contract. The setting defaults on; turning it off is
an explicit compatibility-testing choice, not permission to replace an
unsupported or 3D battle interface.

### Battle screens

Battle adapters use `layer = "battle"` and the same version negotiation and
error isolation as ordinary screens. A battle model may additionally publish
read-only `phase`, `presentation`, `player`, `enemy`, `moves`, `message`,
`wideLayout`, `isVoxelBattle`, and `overlays` fields. `overlays` accepts data
such as:

```lua
overlays = {
  experience = { current = 14, maximum = 100 },
  caughtIndicator = { caught = true },
  catchRates = { pokeball = 18, greatBall = 32, ultraBall = 48 },
}
```

These values are presentation hints only. The source mod calculates them and
continues to own battle validation, timing, callbacks, networking, and state
transitions. Only explicit proof of a 2D WIDE layout can activate the modern
battle presenter. `wideLayout = false`, a missing/unknown marker, standard
160x144 geometry, and `isVoxelBattle = true` all retain the complete
native/source interface. `canSuppressNative` is ignored for `layer = "battle"`.
Malformed or throwing adapters also fall back to the native UI. No third-party
draw callbacks are accepted. See
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

## v2 structured details for shared presenters

An `apiVersion = 2` data-first screen can ask the shared presenter to format
detail data that does not fit the v1 title/row/value shape. This is still not a
custom draw callback: the model is copied as a read-only snapshot and Modern
UI measures, arranges, and draws it.

```lua
return {
  title = "DEXNAV",
  rows = encounterRows,
  index = state.cursor or 1,
  details = {
    species = "Oddish",
    level = "Lv 15 - 17",
    sprite = publicSprite,

    custom_fields = {
      columns = 4,
      data = {
        { label = "HP", value = 45 },
        { label = "ATK", value = 50 },
        { label = "DEF", value = 55 },
        { label = "TOTAL", value = 255, style = "accent" },
      },
    },

    footer_lists = {
      {
        title = "ENCOUNTER",
        items = {
          { label = "GRASS", value = "24%" },
          { label = "TIME", value = "DAY" },
        },
      },
      {
        title = "KNOWN MOVES",
        items = {
          { label = "ABSORB" },
          { label = "SWEET SCENT" },
        },
      },
    },
  },
  layout_options = {
    overflow = "shrink_to_fit",
    max_content_height = "100%",
  },
}
```

`details.custom_fields.data` is an array of `{ label, value, style }` records.
`columns` is the preferred column count; the presenter may reduce it when the
safe width cannot fit measured labels and values. `style = "accent"` uses the
active theme's semantic accent treatment. Unknown style names fall back to
normal detail text.

`details.footer_lists` is reserved before the flexible sprite/details region
is laid out. Its sections stay anchored to the bottom of the detail card while
the sprite region above them shrinks to the remaining measured space. The
outer preset envelope remains stable while the player changes rows or detail
pages; changing the amount of content must not make the whole card jump
between unrelated sizes.

`overflow = "shrink_to_fit"` asks the presenter to reduce flexible content
inside that stable envelope before clipping. `max_content_height = "100%"`
caps the measured content at the card's safe inner height. System-font content
can use the presenter's normal fit steps. Pixel-font content only moves between
whole authored font steps; it is never fractionally scaled. These options are
constraints, not permission to draw outside the card, and the renderer still
uses a final content scissor. If a very short card still cannot fit at the
minimum 1X pixel step, the presenter switches to compact one-line cells,
preserves the bottom footer reservation, and omits lower-priority overflow
instead of allowing sections to overlap.

## v2 isolated custom surfaces

Use a custom surface when the shared rows/details presenter cannot express the
screen at all: for example, a 5x4 spatial grid, live sprite bobbing, a custom
shader, or another coordinate-driven composition. A surface is deliberately a
separate v2 lane. It does not add render callbacks to v1 `screens` or
`extensions`.

The smallest descriptor is:

```lua
mod.exports.gen1ModernUi = {
  apiVersion = 2,
  surfaces = {
    DexNavGrid = {
      match = function(state)
        return state.screenId == "DexNavGrid"
      end,

      model = function(game, state)
        return {
          title = "DEXNAV",
          cells = state.publicCells or {},
          selected = state.cursor or 1,
        }
      end,

      layout = {
        default = {
          virtualWidth = 320,
          virtualHeight = 240,
          preset = "L",
        },
        portrait = {
          virtualWidth = 240,
          virtualHeight = 320,
          preset = "M",
        },
        fit = "contain",
        scaleMode = "integer-fit",
      },

      native = {
        policy = "replace",
        scope = "uiCanvas",
      },

      render = function(model, ctx)
        -- The private canvas is already active. Draw in virtual coordinates.
        love.graphics.print(model.title, 12, 10)
        return true
      end,
    },
  },
}
```

Surface IDs must be non-empty strings. `match`, `model`, and `render` are
required functions. `actions` may contain any non-empty named callbacks;
`surface.input.pointer` is an optional raw-pointer callback for cases that
cannot be represented by regions. `layout`, `native`, and `gallery` remain
data-only.

### Virtual layout and fit

Each surface declares a default virtual canvas. `width`/`height` are accepted
aliases for `virtualWidth`/`virtualHeight`. A canvas must be at least 1x1, no
larger than 2048x2048, and no more than four million pixels. Optional
`landscape` and `portrait` entries override the default dimensions or preset
for that orientation.

Supported presets are `XS`, `S`, `M`, `L`, `XL`, `BATTLE_WIDE`, and
`VIEWPORT`. The current fit policy is `contain`. `integer-fit` prefers a whole
output multiplier and nearest filtering; if the monitor is smaller than the
virtual canvas, it uses the largest safe downscale rather than drawing beyond
the safe viewport. `smooth-fit` permits a fractional fit for non-pixel artwork.
Preset-backed output follows the effective UI scale through 400%, including
4K/5K AUTO values, and is still capped by the safe viewport. Pixel-font glyphs
use whole authored font steps under either mode.

The callback always draws against `ctx.virtual`; it does not need to calculate
window DPI, letterboxing, safe-area offsets, or an inverse pointer transform.
`ctx.output` reports the final monitor-space rectangle for diagnostics only.

### Explicit native ownership

Every surface must choose one native policy:

- `native.policy = "replace"` asks Modern UI to replace the matching native
  `uiCanvas` layer, but only after the complete surface frame succeeds.
- `native.policy = "preserve"` leaves native drawing intact and composites the
  committed surface above it.

If `native.scope` is supplied, its only supported value is `uiCanvas`.
Surfaces do not own the world canvas, a voxel scene, or arbitrary canvases.
Use `replace` only when the source mod's surface completely represents that UI
state. Modern UI may conservatively refuse replacement for an ambiguous mixed
stack; native drawing then remains visible.

### Transactional model and rendering

The model callback receives `(game, state)` and must return a new, cycle-free,
function-free table. Public image, sprite, palette, and shader resources may be
referenced as host objects, but behavior belongs in descriptor callbacks, not
inside the model.

Modern UI renders the snapshot to a private canvas before touching the native
`uiCanvas`. The callback receives `(model, ctx)` and must return `true` to
commit. If matching, model construction, copying, layout, resource setup, or
rendering fails, or the renderer returns anything other than `true`, the
private result is discarded and native rendering remains untouched for that
frame. A failed frame must never leave the player with an invisible menu.

The renderer must not switch canvases, retain a scissor/shader/blend change, or
leave the graphics stack unbalanced. The private canvas and a graphics-state
guard limit accidental leakage, but this is cooperative isolation rather than
a security sandbox.

The render context provides:

| Field | Purpose |
| --- | --- |
| `ctx.frame.id` | Monotonic rendered-frame identifier. |
| `ctx.frame.time` / `ctx.frame.dt` | Host frame time and bounded delta time for animation. Prefer these to calling `love.timer` yourself. |
| `ctx.virtual.width` / `height` | Stable custom coordinate system selected for the current orientation. |
| `ctx.output` | Final safe monitor-space `{ x, y, width, height }` and fit information. |
| `ctx.safe` / `ctx.orientation` | Safe monitor rectangle and the selected `landscape` or `portrait` variant. |
| `ctx.scale` | Effective UI/font scale information, including the whole pixel-font step. |
| `ctx.theme` | A read-only snapshot of active semantic colors and layout tokens. |
| `ctx.fonts.title` / `body` / `caption` | Measured host fonts selected for this surface frame. |
| `ctx.graphics` | The active `love.graphics` table; the private surface canvas is already bound. |
| `ctx.assets.image(value, options)` | Resolves a public image/catalog reference without reading a sibling mod's private path. |
| `ctx.effects` | State-restoring `withShader`, `withPalette`, and `withSilhouette` helpers. |
| `ctx.input` | Region collector for source-owned named actions. |
| `ctx.preview` / `ctx.debug` | Gallery-preview flag and optional bounds reporting. |

Context helpers are closure functions, so call them with dot syntax as shown
below (`ctx.input.region(...)`), not Lua method/colon syntax.

Use the effect helpers as scoped operations:

```lua
local function drawSprite()
  love.graphics.draw(model.sprite, x, y)
end

if model.discovered == false then
  ctx.effects.withSilhouette({ 0, 0, 0, 1 }, drawSprite)
elseif model.palette then
  ctx.effects.withPalette(model.palette, drawSprite)
else
  drawSprite()
end
```

`ctx.effects.withShader(shader, draw, ...)` is available for a source-owned
LÖVE shader.
All three helpers restore the previous shader/palette state even if the draw
function throws; the surface transaction then fails safely.

### Regions, named actions, and modal overlays

Register pointer/touch targets in the same virtual coordinates used to draw:

```lua
ctx.input.region({
  id = "cell-12",
  x = cellX,
  y = cellY,
  w = cellW,
  h = cellH,
  action = "select_cell",
  payload = { index = 12 },
})
```

Modern UI maps the final output rectangle back to virtual coordinates and
routes a successful release to `surface.actions.select_cell(game, state,
payload)`. Region IDs should be stable within the surface. Payloads must be
data-only and are copied before dispatch. The optional raw pointer callback
receives `(game, state, event, modelSnapshot)`, where `event.x/y/dx/dy` are
already transformed to virtual coordinates and `event.inside` reports whether
the pointer is within the fitted output. It is for gestures that need
motion/delta data; ordinary buttons and grid cells should use regions.

A named surface action may return a declarative modal. The descriptor owns all
behavior, while the returned value contains presentation data only:

```lua
actions = {
  open_actions = function(game, state, payload)
    return {
      type = "modal_overlay",
      title = "ACTIONS",
      dim_background = true,
      dim_opacity = 0.4,
      options = {
        { label = "SEARCH", action = "search", payload = payload },
        { label = "REGISTER", action = "register", payload = payload },
      },
    }
  end,
  search = function(game, state, payload)
    return state:search(payload and payload.index)
  end,
  register = function(game, state, payload)
    return state:register(payload and payload.index)
  end,
}
```

`type` must be `modal_overlay`; `options` is an array with string `label` and
optional string `action`. `dim_background` defaults on and `dim_opacity` is
clamped to a safe range. No option may contain a callback. Returning the modal
from an action keeps action functions out of the read-only model.

### UI Gallery fixtures

A surface can register data-only fixtures for the in-game UI Gallery:

```lua
gallery = {
  name = "DEXNAV 5x4 GRID",
  screenId = "DexNavGrid",
  category = "Integration",
  variant = "custom surface v2",
  models = {
    empty = { title = "DEXNAV", cells = {}, selected = 1 },
    sparse = { title = "DEXNAV", cells = sampleCells(1), selected = 1 },
    normal = { title = "DEXNAV", cells = sampleCells(6), selected = 1 },
    full = { title = "DEXNAV", cells = sampleCells(20), selected = 1 },
    overflow = { title = "DEXNAV", cells = sampleCells(32), selected = 20 },
  },
}
```

The fixture keys correspond to the Gallery's EMPTY, SPARSE, NORMAL, FULL, and
OVERFLOW content levels. Build fixture tables while declaring the contract;
do not put `sampleCells` or any other function inside `gallery`. Gallery
preview rendering uses the same isolated surface path and scale/font controls
as the live screen.

See [`examples/custom_surface_v2.lua`](examples/custom_surface_v2.lua) for a
complete 5x4 grid with frame-time bobbing, effect helpers, regions, named
actions, a declarative modal, and Gallery fixtures.

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

The compatibility layer never invokes arbitrary files supplied by another mod
or reaches through private modules. v1 screens/extensions still reject custom
rendering callbacks. A v2 surface accepts exactly one descriptor-owned render
callback and executes it transactionally on a private canvas; it does not
accept callbacks inside model, layout, theme, frame, modal, or Gallery data.
This keeps future source-mod UI files safe to ship alongside their own mods
while preserving a conservative native fallback.

## Testing checklist

Before publishing a contract, test:

1. The source mod is absent and disabled.
2. `apiVersion` is missing, explicitly `1`, explicitly `2`, or an unsupported
   future value; v1 must continue to work without v2 capabilities.
3. `match` returns false, returns malformed values, or throws.
4. `model` changes rows, cursor, scroll, details, portraits, and map markers.
5. Every semantic action still reaches the source mod's validation and
   callbacks.
6. Optional images are missing, animated, palette-aware, or unavailable.
7. Multiple themes and frames can be selected and are removed after reload.
8. Light/dark/high-contrast palettes remain readable with large fonts,
   responsive scaling, pixel fonts, and the seven-pixel frame inset.
9. A v2 surface is tested with both `replace` and `preserve`, renderer/model
   exceptions, a false render result, portrait/landscape, fractional window
   DPI, and a viewport smaller than its virtual canvas.
10. Every v2 pointer region still maps to the drawn virtual rectangle after
    contain fitting, and modal options route only to named source actions.
11. `custom_fields` and bottom-anchored `footer_lists` fit EMPTY through
    OVERFLOW Gallery fixtures at every supported pixel-font step.

The copy-paste starter and current integration templates are available in the
[`docs/examples`](examples/README.md) directory:

- [`gen1_modern_ui_adapter.lua`](examples/gen1_modern_ui_adapter.lua)
- [`dex_radar_adapter.lua`](examples/dex_radar_adapter.lua)
- [`rby_mmo_adapter.lua`](examples/rby_mmo_adapter.lua)
- [`useful_bag_adapter.lua`](examples/useful_bag_adapter.lua)
- [`option_rows_adapter.lua`](examples/option_rows_adapter.lua)
- [`custom_surface_v2.lua`](examples/custom_surface_v2.lua)

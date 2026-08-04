# Gen1 Modern UI

Standalone high-resolution UI overhaul mod for released gen1recomp builds.

This repository contains only the mod and its documentation. It does not
modify the game executable or require a custom engine checkout at runtime.
Install the release asset by extracting `manifest.json` and `main.lua` into
`%APPDATA%\pokemon-love2d\mods\gen1_modern_ui`, or use the included sync script
from a checkout of this repository.

## Highlights

- Responsive portrait and landscape menus with full safe-window layouts.
- Live rows and options, so other mods' menu entries remain visible.
- Theme tokens, density controls, nearest-neighbor artwork, and sprite-pack
  compatibility.
- Useful Dex and Gen 3 Box presenters with square grids and animated authored
  art support.
- Battle presentation remains explicitly WIP and disabled by default.

See [the handoff document](docs/GEN1_MODERN_UI_HANDOFF.md) for the compatibility
contract, layout rules, testing notes, and release checklist.

## Development

The mod source lives in `mods/gen1_modern_ui`. Run the lightweight checks from
the gen1recomp source checkout:

```powershell
npx --yes luaparse -q mods/gen1_modern_ui/main.lua
python tools/modkit.py lint mods/gen1_modern_ui
```

To build the launcher-ready archive, double-click `sync_gen1_modern_ui.cmd` or
run `Compress-Archive` over the contents of `mods/gen1_modern_ui`.

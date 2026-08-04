# Gen1 Modern UI

Standalone high-resolution UI overhaul mod for released
[gen1recomp](https://github.com/bryanthaboi/gen1recomp) builds.

This repository contains only the mod and its documentation. It does not
modify the game executable or require a custom engine checkout at runtime.

## Install the latest release

1. Download the newest `gen1_modern_ui-<version>.zip` from the
   [Releases page](https://github.com/ArmstrongThomas/gen1-modern-ui/releases).
2. Launch gen1recomp and open the **Mods** tab.
3. Choose **Import mod .zip**, select the downloaded archive, and confirm the
   import.
4. Enable **Gen1 Modern UI** under the **UI** section if it is not already
   enabled, then restart the game if prompted.

The launcher handles extraction and installation; users do not need to unpack
the archive manually. Windows users can also use `sync_gen1_modern_ui.cmd` when
working from a source checkout.

## Updates

The mod manifest advertises this repository as
`ArmstrongThomas/gen1-modern-ui`, and every release includes the matching
`gen1_modern_ui-<version>.zip` asset. This lets gen1recomp show the mod's
available versions and offer updates from its Mods panel. The same release
shape is compatible with the community
[gen1recomp mod index](https://github.com/bryanthaboi/gen1recomp-mod-index)
when the listing is enabled there.

## Highlights

- Responsive portrait and landscape menus with full safe-window layouts.
- Live rows and options, so other mods' menu entries remain visible.
- Theme tokens, density controls, nearest-neighbor artwork, and sprite-pack
  compatibility.
- Useful Dex and Gen 3 Box presenters with square grids and animated authored
  art support.
- Battle presentation remains explicitly WIP and disabled by default.

## Compatibility with other mods

The presenter reads live public menu rows rather than replacing other mods'
state or callbacks. It currently supports UI surfaces from mods such as
[Useful Dex](https://github.com/bryanthaboi/gen1recomp/wiki), **Gen 3 Box**, and
the built-in mod manager, while preserving custom entries added by other
authors. Sprite replacement packs such as **Gold_Silver_Sprites** are used when
they are enabled. Unknown or unsupported screens remain vanilla instead of
being forced through an incorrect layout.

See [the handoff document](docs/GEN1_MODERN_UI_HANDOFF.md) for the compatibility
contract, layout rules, testing notes, and release checklist.

## Requests and bug reports

Please [open an issue](https://github.com/ArmstrongThomas/gen1-modern-ui/issues)
for bug reports, compatibility requests, new screen types, themes, or layout
ideas. Include the gen1recomp version, mod versions, screen name, device or
window resolution/orientation, and a screenshot or reproduction path when
possible.

## Development

The mod source lives in `mods/gen1_modern_ui`. Run the lightweight checks from
the gen1recomp source checkout:

```powershell
npx --yes luaparse -q mods/gen1_modern_ui/main.lua
python tools/modkit.py lint mods/gen1_modern_ui
```

To build the launcher-ready archive, double-click `sync_gen1_modern_ui.cmd` or
run `Compress-Archive` over the contents of `mods/gen1_modern_ui`.

## Automated releases

The workflow in `.github/workflows/release.yml` runs on pushes to `main` and
manual dispatches. It validates the manifest and Lua syntax, builds the
launcher-ready zip, and creates a GitHub release only when the manifest version
does not already have a tag. To publish the next release, update the
`version` field in `mods/gen1_modern_ui/manifest.json` (for example, to
`0.1.1`) and push that commit to `main`. Each release includes a commit-based
change log, compatibility notes, quick-start install steps, and the archive's
SHA-256 checksum.

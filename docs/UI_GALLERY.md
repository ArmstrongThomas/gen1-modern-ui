# In-game UI Gallery

The UI Gallery is a Modern UI-owned visual QA screen that renders the real
production presenters against safe synthetic models. It is intended for
layout review, screenshots, and precise bug reports; it does not replace or
mutate the live Party, Bag, save data, battle, network state, or source-mod
screens.

Open it in-game through:

`START` → `MOD MENUS` → `UI SETTINGS` → `ADVANCED` → `UI GALLERY`

The public `gen1_modern_ui` export also provides `openUiGallery(game)` and
`uiGalleryCatalog()` for development tools.

## Controls

| Control | Action |
|---|---|
| Left / Right | Previous / next presenter |
| Up / Down | Empty / sparse / normal / full / overflow content |
| A | Cycle UI scale: 75%, 100%, 125%, 150%, 200%, 300%, 400%, AUTO |
| Select | Cycle font scale |
| Start | Toggle system font / Plain Pixel mode |
| B | Close the gallery |

Scale and font changes are gallery-local overrides. Closing the gallery
restores the player's saved settings without writing each QA step to the save.
Plain Pixel cycles through AUTO and authored 1×, 2×, 3×, and 4× raster steps;
AUTO itself always resolves to one of those whole steps.

## Referencing a screen

The header always shows four identifiers:

- `ID`: stable gallery identifier used in reports and tests.
- `TYPE`: Modern UI presenter kind.
- `SCREEN`: source-style screen ID or state type.
- `VARIANT`: page or phase when one presenter has materially different forms.

For example: `ID battle.wide.moves`, `TYPE battle`, `SCREEN BattleState`,
`VARIANT moves`.

The exported catalog also supplies a fully qualified identifier such as
`gen1_modern_ui.gallery.battle.wide.moves`. The shorter on-screen ID remains
the preferred bug-report label.

`OUTSIDE 0` in the gallery footer is the live bounds diagnostic for the
current preview. A nonzero value means one or more recorded presenter
rectangles escaped the preview safe area and should be included in the report.

## Catalog

| Stable ID | Display name | Type | Screen | Variant |
|---|---|---|---|---|
| `core.dialogue` | Dialogue | `text` | `TextBox` | — |
| `core.choice` | Choice Prompt | `choice` | `ChoiceBox` | — |
| `battle.catch.nickname_prompt` | Catch - Nickname Prompt | `choice` | `TextBox + ChoiceBox` | `catch_nickname` |
| `core.quantity` | Quantity Prompt | `quantity` | `QuantityBox` | — |
| `core.start_menu` | Start Menu | `menu` | `StartMenu` | — |
| `core.list_menu` | Generic List | `list` | `ListMenu` | — |
| `core.options_menu` | Game Options | `options` | `OptionsMenu` | — |
| `manager.mod_list` | Mod Manager | `mod_manager` | `ManagerState` | `list` |
| `manager.detail` | Mod Manager - Detail | `mod_manager` | `ManagerState` | `detail` |
| `manager.options` | Mod Manager - Options | `mod_manager` | `ManagerState` | `options` |
| `manager.permissions` | Mod Manager - Permissions | `mod_manager` | `ManagerState` | `permissions` |
| `manager.errors` | Mod Manager - Errors | `mod_manager` | `ManagerState` | `errors` |
| `manager.apply` | Mod Manager - Apply | `mod_manager` | `ManagerState` | `apply` |
| `manager.confirm` | Mod Manager - Confirmation | `mod_manager` | `ManagerState` | `confirm` |
| `manager.help` | Mod Manager - Option Help | `mod_manager` | `ManagerState` | `help` |
| `manager.option_rows` | Mod Option Rows | `mod_options` | `OptionRows` | — |
| `pokemon.party` | Party | `party` | `PartyMenu` | — |
| `pokemon.party.actions` | Party - Actions | `party` | `PartyMenu` | `actions` |
| `pokemon.summary.status` | Summary - Status | `summary` | `SummaryMenu` | `status` |
| `pokemon.summary.moves` | Summary - Moves | `summary` | `SummaryMenu` | `moves` |
| `pokemon.summary.dvs` | Summary - DVs / Stat Exp | `summary` | `SummaryMenu` | `dvs` |
| `pokemon.summary.extension` | Summary - Additive Page | `summary` | `SummaryMenu` | `extension` |
| `pokemon.trainer_card` | Trainer Card | `trainer_card` | `TrainerCard` | — |
| `pokemon.pokedex` | Pokedex | `pokedex` | `PokedexMenu` | — |
| `pokemon.dex_entry.data` | Dex Entry - Data | `dex_entry` | `DexEntryMenu` | `data` |
| `pokemon.dex_entry.stats` | Dex Entry - Stats | `dex_entry` | `DexEntryMenu` | `stats` |
| `pokemon.dex_entry.moves` | Dex Entry - Moves | `dex_entry` | `DexEntryMenu` | `moves` |
| `inventory.bag` | Bag | `bag` | `BagMenu` | — |
| `inventory.shop` | Shop | `shop_list` | `ShopList` | — |
| `inventory.pc_list` | Player PC | `pc_list` | `PlayerPcList` | — |
| `pokemon.pc_root` | Pokemon PC Actions | `box_root` | `BoxMenu` | — |
| `pokemon.pc_list` | Pokemon PC List | `box_mon_list` | `BoxPokemonList` | — |
| `pokemon.gen3_box` | Gen 3 Box Grid | `gen3_box` | `Gen3Box` | — |
| `pokemon.gen3_box.party` | Gen 3 Box - Party Grid | `gen3_box` | `Gen3Box` | `party` |
| `pokemon.move_learn` | Move Learn | `move_learn` | `MoveLearnMenu` | — |
| `utility.picture_box` | Picture Box | `pic_box` | `PicBox` | — |
| `utility.naming` | Naming | `naming` | `NamingScreen` | — |
| `battle.catch.nickname_entry` | Catch - Nickname Entry | `naming` | `NamingScreen` | `catch_nickname` |
| `utility.town_map` | Town Map - Grid | `town_map` | `TownMap` | `grid` |
| `utility.town_map.list` | Town Map - List | `town_map` | `TownMap` | `list` |
| `utility.town_map.fly` | Town Map - Fly | `town_map` | `TownMap` | `fly` |
| `utility.town_map.area` | Town Map - Area | `town_map` | `TownMap` | `area` |
| `utility.quarantine_report` | Load Report | `quarantine_report` | `QuarantineReport` | — |
| `utility.link` | Link - Menu | `link` | `LinkState` | `menu` |
| `utility.link.code` | Link - Code Entry | `link` | `LinkState` | `codeEntry` |
| `utility.link.address` | Link - Address Entry | `link` | `LinkState` | `addrEntry` |
| `utility.link.notice` | Link - Compatibility Notice | `link` | `LinkState` | `notice` |
| `utility.link.trade` | Link - Trade Party | `link` | `LinkState` | `trade` |
| `utility.link.battle_options` | Link - Battle Options | `link` | `LinkState` | `battleOptions` |
| `integration.dex_radar` | Dex Radar | `dex_radar` | `DexRadar` | — |
| `integration.rby_mmo_profile` | RBY MMO Profile | `rby_mmo_profile` | `RbyMmoProfile` | — |
| `integration.rby_mmo_rank` | RBY MMO Ranking | `rby_mmo_rank` | `RbyMmoRank` | — |
| `integration.rby_mmo_character` | RBY MMO Character | `rby_mmo_char_pick` | `RbyMmoCharPick` | — |
| `integration.external_adapter` | Registered Adapter Rows | `external` | `RegisteredAdapterModel` | `rows` |
| `integration.external_details` | Structured Adapter Details | `external` | `RegisteredAdapterDetails` | `details` |
| `battle.wide.commands` | WIDE Battle - Commands | `battle` | `BattleState` | `commands` |
| `battle.wide.moves` | WIDE Battle - Moves | `battle` | `BattleState` | `moves` |
| `battle.wide.message` | WIDE Battle - Message | `battle` | `BattleState` | `message` |
| `battle.wide.level_up` | WIDE Battle - Level Up | `battle` | `BattleState` | `level_up` |

Integration entries remain available as synthetic previews even when their
source mod is not installed. They exercise Modern UI's compatibility
presenter, not the absent mod's networking or private state implementation.

An active v2 surface may add its own data-only Gallery fixtures. Those entries
use the runtime ID `surface:<owner>:<surface-id>`, type `custom_surface`, and are
removed automatically when the source adapter is disabled, reloaded, or
unregistered. Their EMPTY through OVERFLOW models use the same isolated render
transaction and scale controls as the live surface.

The catch flow intentionally has two IDs. `battle.catch.nickname_prompt`
renders the host's combined TextBox/ChoiceBox question, while
`battle.catch.nickname_entry` renders the NamingScreen reached after choosing
YES. They should be reported separately because they are separate engine
states and can fail independently.

## Content levels

- `EMPTY` exercises a presenter with no rows or records where that state
  supports an empty model.
- `SPARSE` supplies one representative row or record.
- `NORMAL` supplies the expected ordinary amount of content.
- `FULL` fills the normal capacity of Party, Box, and list screens.
- `OVERFLOW` supplies long labels and enough rows to force wrapping or
  scrolling.

Changing the content level deliberately rebuilds the synthetic source model.
Ordinary selection or page movement inside a real screen still uses that
screen's stable preset envelope and must not resize its outer container.

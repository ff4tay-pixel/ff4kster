# CLAUDE.md — FF4kster

Read `AGENTS.md` first for the project layout, build commands and conventions. This file adds the
summary of what the program does now, the disassembly to use for research, verified ROM addresses and
the pitfalls that already cost time.

## What FF4kster is

A FreeBASIC ROM editor for **Final Fantasy IV (FF2US v1.1)**, with a text-mode UI (80x58 cells, `screen 18, 32`)
that draws its font, windows and most graphics from the ROM being edited. Everything is edited in
memory and written only by "Save ROM". `README.md` documents every editor, key and config file for users;
keep it in sync when behavior changes (it has a "Since 0.8" version-history entry to extend).

Editors on the main menu: Features, Spells (with animation preview), Spell Sets, Weapons (with sprite
preview), Armors, Medicines, Tools, Shops, Jobs, **Battle Sprites** (tile/palette editor, BMP export/import),
Characters (full-screen **level up editor** with totals), Commands, Actors, Messages, Events, Triggers and NPCs
(with overview minimaps), Tilesets, Map Info, Maps (paste preview, redo, replace tile, NPC/trigger overlay),
Monsters (sprite preview, reorganized screen), Formations (**battlefield preview**), Encounters, Autobattles,
Solobattles, **Edit World Maps** (overworld, underground, moon: paint, fill, replace, copy/paste preview,
undo, triggers and encounter zones overlay, mouse), plus Search Everywhere, Space Usage, Changed Entries.
CSV export/import and the two ROM comparisons still exist in `subs/csv` and `subs/general` but are hidden
from the menu. The main menu is grouped under headings; `menu_id` maps a row to its entry number and
`AddMainEntry(..., explicit_id)` adds an entry without renumbering the others (World Maps is 31).

## Shared building blocks (use these instead of writing new loops)

- **Entry list tools** (`subs/general/listtools.bas`): `ListInput(menu, kind)` gives a list changed marks, Ctrl-R
  revert, Ctrl-C/V copy/paste, Ctrl-U used-by and Ctrl-Z undo. Kinds with an object type (spells, weapons, ...,
  actors) have per-kind arrays; kinds saved as **a row of text** (`EntryRow` / `ApplyRow`: solobattles,
  autobattles, spell sets, encounters, events) need only those two, so prefer that for new kinds. A new kind
  touches: `KindIndex`, `EntryCount`, `EntryName`, `KindTitle`, `EntryRow`, `ApplyRow`, `IsRowKind`, the array
  sizes, `SnapshotOriginalRows`, the undo cases, `UsageText`, and `ChangedEntries` / `OpenEntry` in `globalsearch.bas`.
- **Help**: one source, `FillHelp` in `mainhelp.bas`, used by the main menu panel and by F1 (`help_entry` is the
  main menu entry of the open editor). Add keys there and in README.
- **Mouse**: `PollMouse` (`functions/mouse.bas`), `BlueMenu.MouseCode` (menus handle clicks themselves),
  `EventKey` for getkey-style loops, `GridMenu.HitTile` for tile grids. `getkey` loops do not see the mouse.
- **Dialogs reused from several screens**: `triggertools.bas` (trigger editing at a tile, teleport spot picker),
  `npctools.bas` (NPC placement dialog, shared with Edit NPCs), `messagetools.bas` (edit a map message's text),
  `eventtools.bas` (event undo, hints, used-by). They take a screenshot with `get`, `cls`, run, then `put` it back.

## Disassembly to use

**https://github.com/everything8215/ff4** is the SNES FF4 disassembly (US v1.1 and JP). This is the reference
for anything about how the game works. (`everything8215/ff2` is the *NES* Final Fantasy II. It does not apply.)

How to use it: `git clone --depth 1` it into a **scratch directory** (not the project), then read:

| Path | What it holds |
|---|---|
| `vanilla/ff4-en-rip.json` | **Data layouts**: ranges, item lengths, field bit masks and pointer tables for most tables. Check this first. |
| `btlgfx/magic.asm` | Spell animations: `ExecAnimScript`, frame drawing, `MagicAnim_NN` effect routines |
| `btlgfx/weapon.asm`, `btlgfx/sprite.asm` | Weapon sprites and hit effects, battle character sprites (poses) |
| `btlgfx/ppu.asm`, `btlgfx/btlgfx.asm` | Monster drawing, boss tilemaps, monster positions, palettes |
| `btlgfx/btlgfx_data.asm` | Small tables in the graphics bank (pose tables, size tables, sprite tile ids) |
| `battle/battle.asm`, `battle/win.asm` | Loading a formation, battle results, `LevelUp` (the exact stat/HP/MP rules) |
| `tools/romtools/data-codec.js`, `gfx.js` | Data and graphics formats (tilemap flags, 3bpp/4bpp) |

The data tables themselves (`data/*.asm`) are **not** in the repo; they are generated from a ROM. Addresses in
the rip JSON and in `.asm` comments are SNES `bank/address` or file offsets: use the conversion below.

## Offset conventions (the easiest way to get a bug)

- The game is **LoROM**: file offset = `bank * 0x8000 + (address - 0x8000)`. `0f/a050` is file `0x7A050`.
- `ff4rom` (and `ByteAt`) **always carry a 0x200 byte header**, even for unheadered files. Constants in the
  code are therefore *file offset + 0x200*. Add it explicitly and re-check the sum (an arithmetic slip of
  2 bytes broke the monster size table once).
- Pointers inside a bank are 16-bit values 0x8000 or higher: add `bankbase - 0x8000`.
- The rip JSON writes ranges as `bank * 0x10000 + address` (e.g. world maps `0x168480`): convert with
  `(a shr 16) * &h8000 + (a and &h7FFF)`, then add `&h200` (`WorldOffset` in `worldmap.bas`).

## ROM tables already decoded (editor offsets, header included)

| Data | Offset | Notes |
|---|---|---|
| Formations | `&h70200` | 8 bytes each; byte 5 = arrangement, byte 7 = cursor arrangement |
| Monster positions | `&h71200` | 256 arrangements x 8 slots; byte = x (high nibble), y (low nibble); top left px = `x*8+16, y*8` |
| Monster graphics props | `&h7CC00` | 4 bytes: size, palette, pointer lo, hi |
| Special (boss) sizes | `&h7D000` | 5 bytes x 64: position (hi nibble x, lo nibble y), size id, palette, tilemap id |
| Monster size table | `&h7015E` | 43 x (width, height) in 8px tiles |
| Boss tilemap pointers | `&h75100` | 57 pointers; tilemap bytes: tile number, `FF` empty, `FE n` run of empty |
| Monster graphics | `&h48200 + ((ptr*8) mod &h40000)` | 3bpp, 24 bytes per tile; a **pointer below 0x8000 means 4bpp** (32 bytes per tile, colors 8-15 from the next palette): only Zeromus's last form and the Dummy |
| Monster palettes | `&hE7000` | 8 colors (15-bit) x 16 bytes each; the game always loads **two** (32 bytes) |
| Spell animation props | `&h7A250` | 4 bytes: palette, graphics, sequence (script), effect |
| Anim graphics / tilemap / palettes | `&h638C0` / `&h675C0` / `&h74D00` | 3bpp tiles; 16-bit map entries (14-bit tile + flip bits); 8-color palettes |
| Anim scripts / frames | pointers at `&h7D7E0` / `&h7DFE0` | see `subs/general/spellanim.bas` header for the script bytecode |
| Weapon sprites | `&hE5B00` | sprite N starts at tile 4N; 8 tiles = two 16x16 frames |
| Weapon visuals (palette, sprite, slash, swing) | `&h7A010` | 4 bytes per weapon |
| Battle character graphics | `&hD0200` | 15 sheets x 0x800, 4bpp; poses: tile table `&h6FB61`, positions `&h6FA61`, pose to position `&h6FA3C` |
| Level up data | pointers `&h7B700`, data from `&h7B728` | 5 bytes per level; rules in `battle/win.asm` |
| World maps | see header of `subs/general/worldmap.bas` | one RLE row per pointer: overworld/underground 256x256, moon 64x64, fixed room 4000h/1D00h/1E80h bytes, only changed worlds are rewritten; the disassembly writes addresses as bank*10000h+address, so convert with `(a shr 16)*&h8000 + (a and &h7FFF)` (+&h200) |

## Features that have non-obvious rules

- **Spell animation** = sequence (a sprite script the editor can play) + effect (a game-code routine the editor
  cannot play; sequences defer to it for things like Comet).
- **Level up**: row L applies when going from level L to L+1; stats capped 99 (amount 7 means -1, floor 1); HP/MP gain = bonus + random 0..bonus/8 (caps 9999/999); TNL is per level.
- **Formations**: slots fill type 1, then 2, then 3 (duplicate types merge their counts); bosses override the arrangement position.
- **Boss tile maps ignore the "tile index MSB" flag for data offsets** (it is only a name-table bit).
- **Boss palette**: the game reads it from the special size entry, never from the monster's own palette byte
  (`btlgfx/ppu.asm`, `BossGfxProp`); that byte is vestigial for bosses. Party members used as enemies use the
  battle sprite sheets.
- **Teleport triggers to the worlds** (destination 251-253): the whole byte that holds X and the facing is the X
  (0-255), facing unused. The `Trigger` type still splits it as `new_x` (6 bits) + `facing`; `TriggerGoesToWorld`.
- **Random battles** are chosen per 32x32 tile zone (overworld 8x8 zones, underground 4x4, moon 2x2); the
  Encounters editor's areas 1-64 / 65-80 / 81-84 are those zones in row order.
- **Fixed limits that the original ROM already fills**: 979 triggers on the normal maps, 82 world triggers,
  12 NPC placements per map plus a shared room. Adding needs a delete first; the editors say so.
- World map rows must decode to exactly their width; the overworld's 00/10/20/30 tiles are a 4-tile shortcut,
  so a lone such tile is written as a run of one. The game also patches a few overworld tiles at run time
  (`ModOverworldTilemap`); the editor shows the stored map.
- Map messages belong to the map (`maps(m).dialogues`): every NPC and trigger on that map that uses a message
  shows an edit of it.
- Save checks space for events, triggers, **map data**, text banks, spell lists; overflow shows a warning and the file is not written.

## Pitfalls (all hit during development)

1. **Image buffers.** Do not `PSET`/`LINE` into an image and then `ImageDestroy` it with no other drawing in
   between: FreeBASIC keeps a dangling "current target" and crashes later, unpredictably. Write pixels through
   `ImageInfo`'s pixel pointer (see `MonsterPutPixel`) or follow with a screen draw.
2. **The font cannot draw `+ = ( ) [ ] < > ; * & "` and `\`**: they appear as `?`. Allowed: letters, digits, space and `! # % ' , - . / : ? _`. Write on-screen help with words ("Minus Plus", "Comma").
3. **Reserved words** as variable names (`command`, `map`, `field`, `out`, `tile`, `run`, `pos`, `imp`, `table`,
   `top` in some places) give confusing compile errors ("Duplicated definition" or "Expected expression").
4. Large local arrays or huge functions made behavior depend on code layout; prefer `dim shared` arrays and small functions.
5. Memory bugs hide: an out-of-bounds write (`monsters(256)` in `SetMoonFlags`) caused random crashes elsewhere. Compile a scratch copy with `fbc -exx` to find them (there are still known out-of-bounds *reads* in `ReadLevelups` that `-exx` stops on).
6. A single-line `if cond then pset ..., array(...)` and similar combined statements are best split into simple steps.
7. **Stale drawing target, second form**: after a routine that creates and destroys an image (the monster preview
   panel) the next menu that builds an image can come out corrupted (the template menu drew as a thin strip).
   End such routines with a draw on the screen itself, e.g. `pset (x, y), point(x, y)`.
8. **Include order matters** (`subs.bas`): a routine can only call what is defined above it; use a `declare` for
   forward references. Method bodies (`methods.bas`) come last, so they can call anything in `subs`.
9. **Line endings**: most source files are CRLF. Scripts that edit them should read, normalise to LF, edit and write
   back the original style. Do not match blank lines that carry trailing spaces (some editors strip them).
10. **Window scaling is not possible** with FreeBASIC's gfxlib here (a resized window does not stretch; the OpenGL
    2D mode never switched on). Do not spend time on it again.
11. Do not drive the real mouse (`SetCursorPos`, `mouse_event`) in tests: it clicks whatever window is under it.

## How to test (there is no unit test suite)

The program is a graphics app, so testing is done with throwaway **harness programs** kept in a scratch
directory, never in the repo: a `.bas` that includes `common/*`, `consts.bas`, `types.bas`, `globals.bas`,
`functions.bas`, `subs.bas`, `methods.bas`, calls `screen 18, 32`, `ReadData(rom)`, draws a screen by calling the
editor's own display code, and writes it with `bsave "x.bmp", 0` (convert and look at it). This catches layout,
decoding and crash problems without a keyboard. Other tricks used:

- Decode data first in Python from the ROM file (offsets there have no header) and compare with the editor.
- **Scripted keys**: copy the repo to the scratchpad, `sed` the `key = inkey` / `getkey` line of the loop under test
  into a `ScriptKey()` that returns keys from an array (and takes a `bsave` screenshot on a marker), and run the
  editor's real loop. Extended keys are `chr(255) + chr(scancode)` (Down 80, Insert 82, Delete 83).
- Screenshots: `bsave "x.bmp", 0` is a 32-bit BMP; Python without PIL can turn it into a PNG with `struct` +
  `zlib` for viewing.
- A harness can call `ApplyDataToROM()` (set `defer_warnings = true`) and compare `ff4rom` before and after to prove
  an unedited game saves byte-identically.
- `lu_script` in `subs/edit/editlevelups.bas` feeds scripted keystrokes to that editor for automated tests.
- Stress loops (all monsters, all formations, all spells) to catch crashes; `fbc -exx` for bounds checks.
- Build with `./build.ps1`; if the exe is locked because the editor is running, compile to another name to check.

## Working agreements

- Keep `README.md` accurate: new keys, editors, config files and ROM behavior belong there.
- Commit only when asked; commit messages end with the co-author line the session gives.
- Never write test files to the drive root or into the repo; use the scratchpad.

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
Solobattles, plus Search Everywhere, Space Usage, Changed Entries. CSV export/import and the two ROM
comparisons still exist in `subs/csv` and `subs/general` but are hidden from the menu.

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

## ROM tables already decoded (editor offsets, header included)

| Data | Offset | Notes |
|---|---|---|
| Formations | `&h70200` | 8 bytes each; byte 5 = arrangement, byte 7 = cursor arrangement |
| Monster positions | `&h71200` | 256 arrangements x 8 slots; byte = x (high nibble), y (low nibble); top left px = `x*8+16, y*8` |
| Monster graphics props | `&h7CC00` | 4 bytes: size, palette, pointer lo, hi |
| Special (boss) sizes | `&h7D000` | 5 bytes x 64: position (hi nibble x, lo nibble y), size id, palette, tilemap id |
| Monster size table | `&h7015E` | 43 x (width, height) in 8px tiles |
| Boss tilemap pointers | `&h75100` | 57 pointers; tilemap bytes: tile number, `FF` empty, `FE n` run of empty |
| Monster graphics | `&h48200 + ((ptr*8) mod &h40000)` | 3bpp, 24 bytes per tile; ptr may be below 0x8000 |
| Monster palettes | `&hE7000` | 8 colors (15-bit) x 16 bytes each |
| Spell animation props | `&h7A250` | 4 bytes: palette, graphics, sequence (script), effect |
| Anim graphics / tilemap / palettes | `&h638C0` / `&h675C0` / `&h74D00` | 3bpp tiles; 16-bit map entries (14-bit tile + flip bits); 8-color palettes |
| Anim scripts / frames | pointers at `&h7D7E0` / `&h7DFE0` | see `subs/general/spellanim.bas` header for the script bytecode |
| Weapon sprites | `&hE5B00` | sprite N starts at tile 4N; 8 tiles = two 16x16 frames |
| Weapon visuals (palette, sprite, slash, swing) | `&h7A010` | 4 bytes per weapon |
| Battle character graphics | `&hD0200` | 15 sheets x 0x800, 4bpp; poses: tile table `&h6FB61`, positions `&h6FA61`, pose to position `&h6FA3C` |
| Level up data | pointers `&h7B700`, data from `&h7B728` | 5 bytes per level; rules in `battle/win.asm` |

## Features that have non-obvious rules

- **Spell animation** = sequence (a sprite script the editor can play) + effect (a game-code routine the editor
  cannot play; sequences defer to it for things like Comet).
- **Level up**: row L applies when going from level L to L+1; stats capped 99 (amount 7 means -1, floor 1); HP/MP gain = bonus + random 0..bonus/8 (caps 9999/999); TNL is per level.
- **Formations**: slots fill type 1, then 2, then 3 (duplicate types merge their counts); bosses override the arrangement position.
- **Boss tile maps ignore the "tile index MSB" flag for data offsets** (it is only a name-table bit).
- Save checks space for events, triggers, **map data**, text banks, spell lists; overflow shows a warning and the file is not written.

## Pitfalls (all hit during development)

1. **Image buffers.** Do not `PSET`/`LINE` into an image and then `ImageDestroy` it with no other drawing in
   between: FreeBASIC keeps a dangling "current target" and crashes later, unpredictably. Write pixels through
   `ImageInfo`'s pixel pointer (see `MonsterPutPixel`) or follow with a screen draw.
2. **The font cannot draw `+ = ( ) [ ] < > ; * & "` and `\`**: they appear as `?`. Allowed: letters, digits, space and `! # % ' , - . / : ? _`. Write on-screen help with words ("Minus Plus", "Comma").
3. **Reserved words** as variable names (`command`, `map`, `field`, `out`, `tile`) give confusing compile errors.
4. Large local arrays or huge functions made behavior depend on code layout; prefer `dim shared` arrays and small functions.
5. Memory bugs hide: an out-of-bounds write (`monsters(256)` in `SetMoonFlags`) caused random crashes elsewhere. Compile a scratch copy with `fbc -exx` to find them (there are still known out-of-bounds *reads* in `ReadLevelups` that `-exx` stops on).
6. A single-line `if cond then pset ..., array(...)` and similar combined statements are best split into simple steps.

## How to test (there is no unit test suite)

The program is a graphics app, so testing is done with throwaway **harness programs** kept in a scratch
directory, never in the repo: a `.bas` that includes `common/*`, `consts.bas`, `types.bas`, `globals.bas`,
`functions.bas`, `subs.bas`, `methods.bas`, calls `screen 18, 32`, `ReadData(rom)`, draws a screen by calling the
editor's own display code, and writes it with `bsave "x.bmp", 0` (convert and look at it). This catches layout,
decoding and crash problems without a keyboard. Other tricks used:

- Decode data first in Python from the ROM file (offsets there have no header) and compare with the editor.
- `lu_script` in `subs/edit/editlevelups.bas` feeds scripted keystrokes to that editor for automated tests.
- Stress loops (all monsters, all formations, all spells) to catch crashes; `fbc -exx` for bounds checks.
- Build with `./build.ps1`; if the exe is locked because the editor is running, compile to another name to check.

## Working agreements

- Keep `README.md` accurate: new keys, editors, config files and ROM behavior belong there.
- Commit only when asked; commit messages end with the co-author line the session gives.
- Never write test files to the drive root or into the repo; use the scratchpad.

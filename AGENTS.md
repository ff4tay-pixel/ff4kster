# AGENTS.md — FF4kster

FF4kster is a ROM editor / hacking tool for **Final Fantasy IV** (confirmed working with FF2US v1.1). It is written in **FreeBASIC** and provides a TUI for editing nearly every aspect of the game: spells, jobs, characters, items, maps, monsters, events, triggers, NPCs, tilesets, formations, encounters, messages, and more.

## Project layout

```
main.bas          Entry point. Sets up the screen, loads the ROM, runs the main menu loop.
consts.bas        Numeric constants (ROM sizes, counts of each game object, screen dims, box-drawing chars).
types.bas         Includes type definitions for game objects (Spell, Weapon, Monster, Formation, ...) and GUI elements.
globals.bas       Shared global state: the ROM byte string, loaded data arrays, overlays, palettes, lists.
functions.bas     Includes small pure-function helpers (LoadROM, ByteAt, FF4Text, etc.).
subs.bas          Includes subroutines grouped by purpose: config reading, ROM read/write, editors.
methods.bas       Includes type methods (ReadFromROM / WriteToROM / Display / Edit for each game object).
common/           Utility libraries: List, Dictionary, Table, heap, queue, stack, set, etc.
config/           30 `.dat` label/config files (elements.dat, spells.dat, shops.dat, tilesets.dat, ...).
```

## Key conventions

- **Language:** FreeBASIC. The project uses `#include once` heavily to compose the program from many `.bas` files. Each top-level file (`main`, `functions`, `subs`, `methods`, `types`, `consts`, `globals`) just includes its sub-modules.
- **ROM access:** The entire ROM is read into the global string `ff4rom` (see `globals.bas`). Bytes are accessed via `ByteAt(offset)` (`functions/byteat.bas`). A dummy 0x200-byte header is prepended for unheadered ROMs.
- **ROM sizes:** Headered ROM = 1,049,088 bytes (0x100200); unheadered = 1,048,576 (0x100000). The program auto-detects and handles both.
- **In-memory model:** Editing happens on in-memory objects. Nothing is written to the ROM until the user selects "Save ROM" in the main menu, which calls `SaveData(filename)` (`subs/write/savedata.bas`).
- **Config files:** Many labels (shop names, element names, spell effects, sequences, etc.) live in `config/*.dat` as `<index> <label>` text lines. They are read at startup and can be edited by the user to change how the editor displays things.
- **Screen:** Fixed 80x58 text-mode canvas (`screen 18, 32`). Custom font/graphics are read from the ROM itself.
- **Controls:** ESC = cancel/back, Enter = confirm, arrows = navigate, Tab = alternate between composite windows, Shift+Enter = swap two entries (where supported).

## How to build / run

- Compiler: `fbc` (FreeBASIC). The verified Windows compiler is FreeBASIC
  1.10.1. Install it with `winget install --id FreeBASIC.FreeBASIC`, or use
  the official installer, then make sure the directory containing `fbc.exe`
  is on `PATH`.
- No build script is committed. Run these commands from the repository root,
  where `main.bas` and `config/` are located:
  `fbc -x ff4kster-console.exe main.bas`
  This is the recommended test build because it keeps a visible console and
  shows the ROM file selector and startup errors.
- For a windowed build without a visible console, use:
  `fbc -s gui -x main.exe main.bas`
  The `-x` option chooses the output executable name; omit it to use the
  compiler default.
- Run the executable from the repository root so relative paths resolve to
  the `config/` directory:
  `./ff4kster-console.exe`
- The program requires a compatible FF2US v1.1 ROM. It opens a file selector
  when started and does not accept a ROM path through the current command-line
  code path. A 1 MiB unheadered ROM or a 1,049,088-byte headered ROM is
  supported. Keep a backup before saving edits.
- Build outputs (`*.exe`) and the local ROM (`ff2.smc`) are ignored by Git.
- A successful build may emit non-fatal warnings about mixed Boolean and
  non-Boolean operands in menu code. They do not prevent the executable from
  being generated.

## Notes for making changes

- When adding a new game object type, you typically need to add:
  1. A type definition under `types/gameobjects/<name>.bas`
  2. A methods file under `types/gameobjects/methods/<name>.bas` (with `ReadFromROM`, `WriteToROM`, `Display`, `Edit`)
  3. Include it in `types.bas` and `methods.bas`
  4. Add a global array in `globals.bas` and a size constant in `consts.bas`
  5. Add an editor entry point under `subs/edit/edit<name>.bas`, included in `subs.bas`
  6. Add a menu option + `case` dispatch in `main.bas`
- ROM offsets are hard-coded throughout. They are specific to FF2US v1.1. Changing them without corresponding ROM research will break the editor.
- Some editors do **not** guard against overflow (events, triggers, map data) — the README warns the user to back up their ROM. Others (NPC placements) do check available space.
- The `common/` directory contains old/experimental versions of data structures (`old/`, `new/`). Prefer the canonical `list.bas`, `dictionary.bas`, `table.bas` over those.
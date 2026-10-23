'Key help shown beside the main menu: general keys, then the keys that matter
' for whichever editor is highlighted.

sub HelpLine(lines() as String, byref n as Integer, s as String)

 n += 1
 lines(n) = s

end sub


dim shared last_help_rows as Integer 'height of the help box drawn last time

sub FillHelp(lines() as String, byref n as Integer, selected as Integer)

 'The key help text, shared by the panel beside the main menu and by F1. selected
 ' is the main menu entry number; 0 gives only the keys that work in every menu.

 HelpLine(lines(), n, "KEYS IN EVERY MENU")
 HelpLine(lines(), n, "Arrows        Move")
 HelpLine(lines(), n, "Enter         Open / select")
 HelpLine(lines(), n, "Esc           Back / cancel")
 HelpLine(lines(), n, "Space         Menu of the actions on an entry")
 HelpLine(lines(), n, "Home / End    First / last entry")
 HelpLine(lines(), n, "PgUp / PgDn   Page up / down")
 HelpLine(lines(), n, "/             Show entry numbers")
 HelpLine(lines(), n, "Ctrl-F        Find entry by name")
 HelpLine(lines(), n, "Ctrl-N        Find next match")
 HelpLine(lines(), n, "Ctrl-G        Go to entry number")
 HelpLine(lines(), n, "F1            Key help for the open editor")
 HelpLine(lines(), n, "X             Hex or decimal in number boxes")
 HelpLine(lines(), n, "Tab           Switch panels in two-pane editors")
 HelpLine(lines(), n, "Mouse         Click selects, click again opens")
 HelpLine(lines(), n, "              Right click = Esc, wheel scrolls")
 if selected = 0 then exit sub
 HelpLine(lines(), n, "")
 HelpLine(lines(), n, "THIS ENTRY")

 select case selected
  case 1
   HelpLine(lines(), n, "Writes your edits to the ROM file.")
   HelpLine(lines(), n, "A * means there are unsaved edits.")
   HelpLine(lines(), n, "Keep a backup of your ROM.")
  case 34
   HelpLine(lines(), n, "Replaces the ROM file with one of the backups")
   HelpLine(lines(), n, "that Save ROM makes (newest first). The ROM as")
   HelpLine(lines(), n, "it is now is backed up first. FF4kster then")
   HelpLine(lines(), n, "starts again. Unsaved edits are lost.")
  case 35
   HelpLine(lines(), n, "Deletes one backup, or all of them, of this")
   HelpLine(lines(), n, "ROM. The list shows date, time and size.")
  case 2
   HelpLine(lines(), n, "Item ranges: which items are two-handed,")
   HelpLine(lines(), n, "bows, arrows, shields, helmets, etc.")
  case 3, 5 to 8
   HelpLine(lines(), n, "Yellow names are changed since load.")
   HelpLine(lines(), n, "Ctrl-R  Revert entry   Ctrl-U  Where used")
   HelpLine(lines(), n, "Ctrl-C / V  Copy / paste entry")
   HelpLine(lines(), n, "Ctrl-Z  Undo the last change in this list")
   if selected <= 6 then HelpLine(lines(), n, "Shift-Enter twice swaps two entries")
   HelpLine(lines(), n, "Enter opens the entry's editor.")
   if selected = 3 then HelpLine(lines(), n, "The panel plays the animation sequence.")
   if selected = 5 then HelpLine(lines(), n, "The panel shows the weapon sprite.")
  case 4
   HelpLine(lines(), n, "Enter opens the entry's editor.")
   HelpLine(lines(), n, "Yellow names are changed since load.")
   HelpLine(lines(), n, "Ctrl-R revert  Ctrl-C / V copy / paste")
   HelpLine(lines(), n, "Ctrl-Z undo the last change in this list")
  case 9
   HelpLine(lines(), n, "Edit what each shop sells.")
   HelpLine(lines(), n, "Yellow names are changed since load.")
   HelpLine(lines(), n, "Ctrl-R revert  Ctrl-C / V copy / paste")
   HelpLine(lines(), n, "Ctrl-Z undo the last change in this list")
  case 10
   HelpLine(lines(), n, "Enter opens the entry's editor.")
   HelpLine(lines(), n, "Yellow names are changed since load.")
   HelpLine(lines(), n, "Ctrl-R revert  Ctrl-C / V copy / paste")
   HelpLine(lines(), n, "Ctrl-Z undo the last change in this list")
   HelpLine(lines(), n, "In sub-menus: Tab switches between boxes.")
  case 36
   HelpLine(lines(), n, "Enter opens the formulas of the highlighted")
   HelpLine(lines(), n, "line. Its settings are listed on the right.")
   HelpLine(lines(), n, "Enter on a setting changes it, Esc goes back.")
   HelpLine(lines(), n, "A setting that says custom code was changed by")
   HelpLine(lines(), n, "something else, it is left alone.")
   HelpLine(lines(), n, "Ctrl-R reverts the line, Ctrl-Z undoes the last")
   HelpLine(lines(), n, "change, Space opens a menu with both.")
  case 13 to 14
   HelpLine(lines(), n, "Enter opens the entry's editor.")
   HelpLine(lines(), n, "Yellow names are changed since load.")
   HelpLine(lines(), n, "Ctrl-R revert  Ctrl-C / V copy / paste")
   HelpLine(lines(), n, "Ctrl-Z undo the last change in this list")
   HelpLine(lines(), n, "In sub-menus: Tab switches between boxes.")
  case 12
   HelpLine(lines(), n, "Enter opens the entry's editor.")
   HelpLine(lines(), n, "Edit level up data opens a full screen table")
   HelpLine(lines(), n, "with a cursor you can move to any value, and")
   HelpLine(lines(), n, "the total stats, HP, MP and EXP after each")
   HelpLine(lines(), n, "level up. The keys are listed at its bottom.")
  case 11
   HelpLine(lines(), n, "Edit the in-battle sprite of each character.")
   HelpLine(lines(), n, "Enter edits a tile, PgUp / PgDn changes the")
   HelpLine(lines(), n, "pose preview, , and . change the palette,")
   HelpLine(lines(), n, "P edits the palette colors. The last two list")
   HelpLine(lines(), n, "entries export / import one BMP per character")
   HelpLine(lines(), n, "with all its poses. The color table of each BMP")
   HelpLine(lines(), n, "is its palette, so keep the color numbers.")
   HelpLine(lines(), n, "Golbez and Anna are not included yet.")
  case 15
   HelpLine(lines(), n, "Pick a bank (a map first for bank 2),")
   HelpLine(lines(), n, "then a message. Enter edits it.")
   HelpLine(lines(), n, "Space  Menu: find text, add, insert,")
   HelpLine(lines(), n, "       delete, move, copy, revert, undo,")
   HelpLine(lines(), n, "       where it is used.")
   HelpLine(lines(), n, "Yellow messages differ from the ROM.")
   HelpLine(lines(), n, "Esc in the text window: done, insert")
   HelpLine(lines(), n, "a code, or discard.")
  case 16
   HelpLine(lines(), n, "Tab        Preview / pick the linked map")
   HelpLine(lines(), n, "Shift-Enter marks an event, Insert appends")
   HelpLine(lines(), n, "           its script to the current one")
   HelpLine(lines(), n, "In scripts: Insert / Delete / Backspace")
   HelpLine(lines(), n, "edit commands, Tab switches script,")
   HelpLine(lines(), n, "Ctrl-C / V copy / paste a command,")
   HelpLine(lines(), n, "Ctrl-Z / Y undo / redo.")
   HelpLine(lines(), n, "List: yellow = changed, Ctrl-R revert,")
   HelpLine(lines(), n, "Ctrl-C / V copy event, Ctrl-U used by.")
  case 17
   HelpLine(lines(), n, "Tab        Toggle the minimap cursor")
   HelpLine(lines(), n, "Insert     Add a trigger")
   HelpLine(lines(), n, "Delete     Remove the trigger")
   HelpLine(lines(), n, "Shift-Enter marks a trigger to swap.")
   HelpLine(lines(), n, "Event call menu: Tab to the messages,")
   HelpLine(lines(), n, "E edits the text of the selected one.")
  case 18
   HelpLine(lines(), n, "Tab        Toggle the minimap cursor")
   HelpLine(lines(), n, "Insert     Add an NPC / placement")
   HelpLine(lines(), n, "Delete     Remove it")
   HelpLine(lines(), n, "Speech menu: Tab to the messages, E edits")
   HelpLine(lines(), n, "the text of the selected one.")
  case 19
   HelpLine(lines(), n, "Tab        Edit the palette")
  case 20
   HelpLine(lines(), n, "Enter opens the map's properties.")
  case 21
   HelpLine(lines(), n, "J  Jump to map number   F  Find map name")
   HelpLine(lines(), n, "I  Grid details         Backspace  Erase map")
   HelpLine(lines(), n, "In the map editor:")
   HelpLine(lines(), n, "Tab          Map / tile palette")
   HelpLine(lines(), n, "Enter        Place tile    Space  Fill")
   HelpLine(lines(), n, "Backspace    Pick tile under cursor")
   HelpLine(lines(), n, "Shift-Arrow  Select an area")
   HelpLine(lines(), n, "Ctrl-C / V   Copy / paste preview, Enter places")
   HelpLine(lines(), n, "Ctrl-Z / Y   Undo / redo")
   HelpLine(lines(), n, "R            Replace all of the tile under the")
   HelpLine(lines(), n, "             cursor with the palette tile")
   HelpLine(lines(), n, "O            Show NPCs and triggers on the map")
   HelpLine(lines(), n, "T            Edit trigger  Insert / Delete add / remove")
   HelpLine(lines(), n, "N            Edit NPC  Shift-Insert / Delete add / remove")
   HelpLine(lines(), n, "Mouse: click paints, drag keeps painting,")
   HelpLine(lines(), n, "right click picks the tile, click the tile")
   HelpLine(lines(), n, "palette to choose a tile, wheel moves up / down.")
  case 22
   HelpLine(lines(), n, "Enter opens the monster's boxes: Up Down move")
   HelpLine(lines(), n, "through every row, Tab or 1-6 jump to a box,")
   HelpLine(lines(), n, "Enter edits the row, Space switches Boss or an")
   HelpLine(lines(), n, "extra on / off, L regular / lunar AI bank,")
   HelpLine(lines(), n, "PgUp / PgDn other monster, Esc")
   HelpLine(lines(), n, "back to the list. Box 6 opens the AI editor.")
   HelpLine(lines(), n, "In the list: yellow means changed, Ctrl-R")
   HelpLine(lines(), n, "revert, Ctrl-U where used, Ctrl-C / V copy /")
   HelpLine(lines(), n, "paste, Ctrl-Z undo the last change.")
   HelpLine(lines(), n, "The picture of the monster is shown at the top.")
  case 23
   HelpLine(lines(), n, "Enter opens the entry's editor.")
   HelpLine(lines(), n, "Yellow names are changed since load.")
   HelpLine(lines(), n, "Ctrl-R revert  Ctrl-C / V copy / paste")
   HelpLine(lines(), n, "Ctrl-Z undo the last change in this list")
   HelpLine(lines(), n, "Ctrl-U shows the areas that use it.")
  case 24 to 26
   HelpLine(lines(), n, "Enter opens the entry's editor.")
   HelpLine(lines(), n, "Yellow names are changed since load.")
   HelpLine(lines(), n, "Ctrl-R revert  Ctrl-C / V copy / paste")
   HelpLine(lines(), n, "Ctrl-Z undo the last change in this list")
   HelpLine(lines(), n, "Autobattle scripts: Insert / Delete edit")
   HelpLine(lines(), n, "commands.")
  case 27
   HelpLine(lines(), n, "Type part of a spell, item or monster name,")
   HelpLine(lines(), n, "pick a match, and its editor opens on it.")
  case 28
   HelpLine(lines(), n, "Shows how full each fixed ROM area is")
   HelpLine(lines(), n, "events, triggers, text, descriptions.")
   HelpLine(lines(), n, "Over 100% means Save ROM will refuse.")
  case 29
   HelpLine(lines(), n, "Lists every spell, item, monster, shop,")
   HelpLine(lines(), n, "formation and job you changed since loading,")
   HelpLine(lines(), n, "pick one to open it.")
  case 33
   HelpLine(lines(), n, "Edit a monster's picture and palette. Enter")
   HelpLine(lines(), n, "picks a monster: Arrows move, 0-9 paint a color,")
   HelpLine(lines(), n, "Space paints with the brush, F fills, X Y flip a")
   HelpLine(lines(), n, "plain monster, Ctrl-Z undo, Ctrl-R revert, PgUp /")
   HelpLine(lines(), n, "PgDn change monster, P edits the palette colors")
   HelpLine(lines(), n, "and Bracket keys move a color with its pixels.")
   HelpLine(lines(), n, "E / I export / import a BMP.")
   HelpLine(lines(), n, "The mouse paints. Sizes are not changed here.")
   HelpLine(lines(), n, "Monsters that share graphics or a palette all")
   HelpLine(lines(), n, "change; the screen says how many.")
  case 37
   HelpLine(lines(), n, "Edit the walking sprites of the party and the")
   HelpLine(lines(), n, "NPCs. Enter edits a sheet: Arrows move, 0-7 paint")
   HelpLine(lines(), n, "a color, Space paints with the brush, F fills,")
   HelpLine(lines(), n, "X Y flip a frame, Ctrl-C / V copy a frame,")
   HelpLine(lines(), n, "Ctrl-Z undo, PgUp / PgDn change sheet, , and .")
   HelpLine(lines(), n, "change the palette, P edits its colors.")
   HelpLine(lines(), n, "The last two list entries export / import BMPs.")
   HelpLine(lines(), n, "A sheet has no palette of its own: the maps pick")
   HelpLine(lines(), n, "it (the window shows which). Your pick is kept")
   HelpLine(lines(), n, "in config/fieldpalettes.dat. A palette color")
   HelpLine(lines(), n, "change reaches every sprite using that palette.")
   HelpLine(lines(), n, "In the palette editor the bracket keys move a")
   HelpLine(lines(), n, "color and the pixels follow, asking first.")
  case 32
   HelpLine(lines(), n, "Edit the 32x32 faces shown in the status, item")
   HelpLine(lines(), n, "and magic menus. Enter edits a portrait:")
   HelpLine(lines(), n, "Arrows move, 0-7 paint a color, Space paints")
   HelpLine(lines(), n, "with the brush, F fills, X Y flip, Ctrl-Z undo,")
   HelpLine(lines(), n, "PgUp / PgDn change portrait, , and . change the")
   HelpLine(lines(), n, "palette, P edits the palette colors. The last two")
   HelpLine(lines(), n, "list entries export / import one BMP per portrait.")
   HelpLine(lines(), n, "The color table of each BMP is its palette, so")
   HelpLine(lines(), n, "keep the color numbers.")
  case 31
   HelpLine(lines(), n, "Pick a world, Enter edits it like a map:")
   HelpLine(lines(), n, "Tab        Map / tile palette")
   HelpLine(lines(), n, "Enter      Place tile    Space  Fill")
   HelpLine(lines(), n, "Backspace  Pick tile under cursor")
   HelpLine(lines(), n, "Shift-Arrow  Select a block")
   HelpLine(lines(), n, "Ctrl-C / V   Copy / paste preview, Enter places")
   HelpLine(lines(), n, "Ctrl-Z / Y   Undo / redo")
   HelpLine(lines(), n, "R          Replace all of the tile")
   HelpLine(lines(), n, "O          Overlay: triggers, encounter zones")
   HelpLine(lines(), n, "T          Edit the trigger under the cursor")
   HelpLine(lines(), n, "Insert / Delete  Add / remove a trigger")
   HelpLine(lines(), n, "Ctrl-Arrow  Jump 16 tiles    Esc  Back")
  case else
   HelpLine(lines(), n, "Leave the editor. You are asked to save")
   HelpLine(lines(), n, "if there are unsaved edits.")
 end select

 

end sub


sub DrawMainHelp(selected as Integer)

 dim x as Integer = 28
 dim y as Integer = 0
 dim w as Integer = 50
 dim lines(1 to 40) as String
 dim n as Integer

 FillHelp(lines(), n, selected)

'The box is as tall as its text, so wipe whatever the previous (taller) box left below it
 screenlock
 if last_help_rows > n + 2 then line (x * 8, (y + n + 2) * 8)-((x + w + 2) * 8 - 1, (y + last_help_rows) * 8 - 1), RGB(0, 0, 0), bf
 BlueBox(x, y, w, n)
 for i as Integer = 1 to n
  WriteText(FF4Text(left(lines(i), w - 1)), x + 1, y + i, iif(lines(i) = "KEYS IN EVERY MENU" or lines(i) = "THIS ENTRY", 14, 15))
 next
 screenunlock
 last_help_rows = n + 2

end sub

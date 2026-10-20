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
 HelpLine(lines(), n, "Home / End    First / last entry")
 HelpLine(lines(), n, "PgUp / PgDn   Page up / down")
 HelpLine(lines(), n, "/             Show entry numbers")
 HelpLine(lines(), n, "Ctrl-F        Find entry by name")
 HelpLine(lines(), n, "Ctrl-N        Find next match")
 HelpLine(lines(), n, "Ctrl-G        Go to entry number")
 HelpLine(lines(), n, "F1            Key help for the open editor")
 HelpLine(lines(), n, "X            Hex or decimal in number boxes")
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
  case 2
   HelpLine(lines(), n, "Item ranges: which items are two-handed,")
   HelpLine(lines(), n, "bows, arrows, shields, helmets, etc.")
  case 3, 5 to 8
   HelpLine(lines(), n, "Yellow names are changed since load.")
   HelpLine(lines(), n, "Ctrl-R  Revert entry   Ctrl-U  Where used")
   HelpLine(lines(), n, "Ctrl-C / V  Copy / paste entry")
   HelpLine(lines(), n, "Ctrl-Z  Undo the last change in this list")
   HelpLine(lines(), n, "Shift-Enter twice swaps two entries")
   HelpLine(lines(), n, "spells, weapons, armors.")
   HelpLine(lines(), n, "Enter opens the entry's editor.")
   HelpLine(lines(), n, "Spells: the panel plays the animation sequence.")
   HelpLine(lines(), n, "Weapons: the panel shows the weapon sprite.")
  case 4
   HelpLine(lines(), n, "Enter opens the entry's editor.")
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
   HelpLine(lines(), n, "with all its poses. The 16 pixels in the top")
   HelpLine(lines(), n, "right corner of each BMP are its palette colors.")
   HelpLine(lines(), n, "Golbez and Anna are not included yet.")
  case 15
   HelpLine(lines(), n, "Pick a map, then a message.")
   HelpLine(lines(), n, "Shift-Enter marks a message to swap.")
   HelpLine(lines(), n, "Insert adds a message, Delete removes.")
  case 16
   HelpLine(lines(), n, "Tab        Preview / pick the linked map")
   HelpLine(lines(), n, "Shift-Enter marks an event, Insert appends")
   HelpLine(lines(), n, "           its script to the current one")
   HelpLine(lines(), n, "In scripts: Insert / Delete / Backspace")
   HelpLine(lines(), n, "edit commands, Tab switches script.")
  case 17
   HelpLine(lines(), n, "Tab        Toggle the minimap cursor")
   HelpLine(lines(), n, "Insert     Add a trigger")
   HelpLine(lines(), n, "Delete     Remove the trigger")
   HelpLine(lines(), n, "Shift-Enter marks a trigger to swap.")
  case 18
   HelpLine(lines(), n, "Tab        Toggle the minimap cursor")
   HelpLine(lines(), n, "Insert     Add an NPC / placement")
   HelpLine(lines(), n, "Delete     Remove it")
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
   HelpLine(lines(), n, "Mouse: click paints, drag keeps painting,")
   HelpLine(lines(), n, "right click picks the tile, click the tile")
   HelpLine(lines(), n, "palette to choose a tile, wheel moves up / down.")
  case 22
   HelpLine(lines(), n, "Enter opens the monster's editor.")
   HelpLine(lines(), n, "Yellow means changed.  Ctrl-R revert, Ctrl-U")
   HelpLine(lines(), n, "where used, Ctrl-C / V copy / paste,")
   HelpLine(lines(), n, "Ctrl-Z undo the last change in the list.")
   HelpLine(lines(), n, "Tab switches between the flag lists and")
   HelpLine(lines(), n, "their details.")
   HelpLine(lines(), n, "In Edit AI: L switches between the regular")
   HelpLine(lines(), n, "and the lunar AI script bank.")
   HelpLine(lines(), n, "Sprite Image exports / imports a BMP of the monster.")
  case 23
   HelpLine(lines(), n, "Enter opens the entry's editor.")
   HelpLine(lines(), n, "Yellow names are changed since load.")
   HelpLine(lines(), n, "Ctrl-R revert  Ctrl-C / V copy / paste")
   HelpLine(lines(), n, "Ctrl-Z undo the last change in this list")
   HelpLine(lines(), n, "Ctrl-U shows the areas that use it.")
  case 24 to 26
   HelpLine(lines(), n, "Enter opens the entry's editor.")
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
